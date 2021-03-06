require_relative '../utils.rb'
require_relative '../console.rb'

#
# Bootstraps a stack. 
#
def bootstrap(aws_connection, config, input, options_hash)
  ops = OpsWorks.build(aws_connection)
  stack_name = config['stack']['name']

  # check if stack already exists
  existing_stack = ops.find_stack stack_name
  if existing_stack
    if input.choice("A stack with the name #{stack_name} already exists. Do you want to delete it or abort?", "da") == 'a'
      exit 1
    end
    existing_stack.delete
  end

  bootstrap_stack(ops, config, input, options_hash) 

  if not options_hash[:start_instances]
    puts "\nNot starting instances because --start was not given"
  end

end

# Creates a new stack from the given config. If a stack with the given name already
# exists, no exception is thrown and you have two stacks with the same name.
def bootstrap_stack(ops, config, input, options_hash)
  puts "Creating stack #{config['stack']['name']} ..."
  stack = ops.create_stack(config['stack'])

  if config['permissions']
    stack.grant_access(config['permissions'])
  else
    puts "Warning! No permissions defined in config. Granting full access to everyone."
    stack.grant_full_access   
  end

  layers = []
  config['layers'].each do |l|
    layer_aws_config = l['config']
    layer = stack.create_layer(layer_aws_config)

    if not l.has_key?('instances')
      puts "Warning! no instances key for layer #{layer_aws_config['name']}"
    else
      l['instances'].each do |i|
        layer.create_instance(i)
      end
      layers.push(layer)
    end

    if l['elb']
      stack.create_elb(l['elb']) if options_hash[:create_elbs]
      layer.attach_elb(l['elb']['name']) if options_hash[:attach_elb]
      update_alarms(l['elb']['alarms']) if l['elb']['alarms']
    end

    if l['load_based_auto_scaling'] and l['load_based_auto_scaling']['enabled']
      layer.configure_load_based_auto_scaling(config['load_based_auto_scaling'], l, {:enable => options_hash[:enable_auto_scaling]})
    end

    if l['time_based_auto_scaling'] and l['time_based_auto_scaling']['enabled']
      layer.configure_time_based_auto_scaling(config['time_based_auto_scaling'], l)
    end

  end

  config['apps'].each do |a, value|
    stack.create_app(a, config['apps'][a])
  end

  if options_hash[:start_instances]
    instances = []

    layers.each do |l|
      started = l.send_start
      instances += started

      if options_hash[:load_instances_to_start] and options_hash[:load_instances_to_start][l.name] > 0
        started_load_instances = l.start_load_instances(options_hash[:load_instances_to_start][l.name])
        instances += started_load_instances
      end
    end

    ops.wait_for_instances_status(instances, "online", ["stopped", "requested", "pending", "booting", "running_setup"])
  end

  puts "\n\nStack #{config['stack']['name']} successfully created."
  return stack
end

def update_alarms(alarms)
  puts "Updating alarms..."
  cw_client = Aws::CloudWatch::Client.new
  alarms.each do |alarm|
    alarm = Hash.transform_keys_to_symbols(alarm)
    cw_client.put_metric_alarm(alarm)
    puts "updated alarm #{alarm[:alarm_name]}" 
  end
end

