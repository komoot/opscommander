require_relative '../utils.rb'
require_relative '../console.rb'

#
# Bootstraps a stack. 
#
def bootstrap(aws_connection, config, input, options_hash)
  ops = OpsWorks.new(aws_connection)
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

def validate_load_based_auto_scaling_config(config, layer_config) 
  raise "Key 'load_based_auto_scaling' not found in configuration!" if not config['load_based_auto_scaling'] 
  lb_config_name = layer_config['load_based_auto_scaling']['config']
  raise "No load-based configuration with the name '#{lb_config_name}' found!" if not config['load_based_auto_scaling'][lb_config_name]
  
  instances = layer_config['instances'].select{|i| i['auto_scaling_type'].eql? 'load'}
  raise "Load-based auto scaling was enabled but no 'load' instances defined!" if instances.empty?
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
    aws_instances = l['instances']
    layer = stack.create_layer(layer_aws_config)
    aws_instances.each do |i|
      layer.create_instance(i)
    end
    layers.push(layer)

    if l['elb']
      stack.create_elb(l['elb']) if options_hash[:create_elb]
      layer.attach_elb(l['elb']['name']) if options_hash[:attach_elb]
      update_alarms(l['elb']['alarms']) if l['elb']['alarms']
    end

    if l['load_based_auto_scaling'] and l['load_based_auto_scaling']['enabled'] and options_hash[:enable_auto_scaling]
      validate_load_based_auto_scaling_config(config, l)
      lb_config_name = l['load_based_auto_scaling']['config']
      layer.enable_load_based_auto_scaling(config['load_based_auto_scaling'][lb_config_name]) 
    end

  end

  config['apps'].each do |a, value|
    stack.create_app(a, config)
  end

  if options_hash[:start_instances]
    instances = []
    layers.each do |l|
      started = l.send_start
      instances += started
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

