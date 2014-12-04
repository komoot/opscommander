require 'erb'
require 'base64'
require 'poll'

require_relative '../console.rb'

#
# Bootstraps a stack. 
#
def bootstrap(aws_connection, config, start_instances, input, create_elb=false)
  if config.has_key?(:plain_ec2)
    # experimental feature: set up a plain ec2 stack using autoscaling and launch configurations
    bootstrap_plainec2(aws_connection, config[:plain_ec2], start_instances, input, create_elb)
  else
    bootstrap_opsworks(aws_connection, config, start_instances, input, create_elb)
  end
end

#
# Bootstraps an opsworks stack
#
def bootstrap_opsworks(aws_connection, config, start_instances, input, create_elb=false)
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

  bootstrap_stack(ops, config, input, start_instances, true, create_elb)

  if not start_instances
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
def bootstrap_stack(ops, config, input, start_instances, attach_elb=true, create_elb=false)
  # create new stack
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
      stack.create_elb(l['elb']) if create_elb
      layer.attach_elb(l['elb']['name']) if attach_elb
      update_alarms(l['elb']['alarms']) if l['elb']['alarms']
    end

    if l['load_based_auto_scaling'] and l['load_based_auto_scaling']['enabled']
      validate_load_based_auto_scaling_config(config, l)
      lb_config_name = l['load_based_auto_scaling']['config']
      layer.enable_load_based_auto_scaling(config['load_based_auto_scaling'][lb_config_name]) 
    end

  end

  config['apps'].each do |a, value|
    stack.create_app(a, config)
  end

  #start all instances if needed
  if start_instances
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
  puts "Updateing alarms..."
  cw_client = Aws::CloudWatch::Client.new
  alarms.each do |alarm|
    alarm = Hash.transform_keys_to_symbols(alarm)
    cw_client.put_metric_alarm(alarm)
    puts "updated alarm #{alarm[:alarm_name]}" #not available: if aws_connection.verbose
  end
end

# keys to symbols for new Aws sdk
class Hash
  #take keys of hash and transform those to a symbols
  def self.transform_keys_to_symbols(value)
    if value.is_a?(Array)
      array = value.map{|x| x.is_a?(Hash) || x.is_a?(Array) ? Hash.transform_keys_to_symbols(x) : x}
      return array
    elsif value.is_a?(Hash)
      hash = value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
      return hash
    end
    return value
  end
end

#
# Bootstrap a plain ec2 stack using autoscaling and launch configurations
# experimental feature
# TODO: create a aws lib once the use case is settled.
#
def bootstrap_plainec2(aws_connection, config, start_instances, input, create_elb)
  as_client = Aws::AutoScaling::Client.new
  elb_client = Aws::ElasticLoadBalancing::Client.new
  


  raise "missing 'auto_scaling_group_name'" if not config[:autoscaling_group][:auto_scaling_group_name]

  existing_group = as_client.describe_auto_scaling_groups({
        :auto_scaling_group_names => [config[:autoscaling_group][:auto_scaling_group_name]]
     })[:auto_scaling_groups].first

  if existing_group
    if input.choice("An autoscaling group '#{existing_group['auto_scaling_group_name']}' already exists. Do you want to delete it or abort?", "da") == 'a'
      exit 1
    end

    as_client.delete_auto_scaling_group({
        :auto_scaling_group_name => config[:autoscaling_group][:auto_scaling_group_name],
        :force_delete => true
      })

    puts "waiting for #{config[:autoscaling_group][:auto_scaling_group_name]} to be deleted"
    Poll.poll(10*60, 5) do
      print "."
      group = as_client.describe_auto_scaling_groups({
        :auto_scaling_group_names => [config[:autoscaling_group][:auto_scaling_group_name]]
      })[:auto_scaling_groups].first
      success = (group.nil?)
    end
    puts " done"
    # wait ...
  end

  # always delete launch configuration (might be from a failed bootstrap before)
  existing_launch_configuration = as_client.describe_launch_configurations({
      :launch_configuration_names => [config[:launch_configuration][:launch_configuration_name]]
      })[:launch_configurations].first
  
  if existing_launch_configuration
    as_client.delete_launch_configuration({
        :launch_configuration_name => config[:launch_configuration][:launch_configuration_name]
        }) 
  end

  puts "creating launch-config '#{config[:launch_configuration][:launch_configuration_name]}' and autoscaling-group '#{config[:autoscaling_group][:auto_scaling_group_name]}'..."
  lconfig = config[:launch_configuration]
  lconfig[:user_data] = parse_userdata(lconfig[:user_data])
  as_client.create_launch_configuration(lconfig)

  if not start_instances
    config[:autoscaling_group][:min_size] = 0
    config[:autoscaling_group][:max_size] = 0
    config[:autoscaling_group][:desired_capacity] = 0
  end

  as_client.create_auto_scaling_group(config[:autoscaling_group])

  if start_instances
    if not config[:autoscaling_group][:desired_capacity] > 0
      raise "illegal value for desired_capacity #{config[:autoscaling_group][:desired_capacity]}"
    end
    puts "waiting for instances in '#{config[:autoscaling_group][:auto_scaling_group_name]}' to boot..."
    Poll.poll(45*60, @verbose ? 5 : 15) do
      instances = as_client.describe_auto_scaling_groups({
        :auto_scaling_group_names => [config[:autoscaling_group][:auto_scaling_group_name]]
      })[:auto_scaling_groups].first[:instances]

      success = false
      if instances.length == 0
        print " waiting for instances ...\r"
      else
        print " " + instances.map { |i| "(#{i[:instance_id]} #{i[:lifecycle_state]}" }.join(" ") + "\r"
        success = check_instances_have_state?(instances.map{|i| i[:lifecycle_state]}, "InService")
      end
      success
    end

    elb = config[:autoscaling_group][:load_balancer_names].first
    if elb
      puts "waiting for instances to be healty in elb '#{elb}'"
      Poll.poll(45*60, @verbose ? 5 : 15) do
        instances = elb_client.describe_instance_health({ :load_balancer_name => elb })[:instance_states]

        success = false
        if instances.length == 0
          print " no instances in elb...\r"
        else
          print " " + instances.map { |i| "(#{i[:instance_id]} #{i[:state]}" }.join(" ") + "\r"
          success = check_instances_have_state?(instances.map{|i| i[:state]}, "InService")
        end
        success
      end
    end

    print "\n"
    puts "All instances are running."
  end
  # wait for instances ...
  puts "done..."
end

# takes a list of user data files and creates a base64 encoded multipart message
def parse_userdata(files)
  content = "Content-Type: multipart/mixed; boundary=\"===============7530540225998998152==\"\nMIME-Version: 1.0\n\n"
  files.each do |file|
    content += "--===============7530540225998998152==\n"
    raise "missing content_type" if not file[:content_type]
    raise "missing content" if not file[:content]
    raise "missing filename" if not file[:filename]
    content += "Content-Type: #{file[:content_type]}; charset=\"us-ascii\"\n"
    content += "MIME-Version: 1.0\n"
    content += "Content-Transfer-Encoding: 7bit\n"
    content += "Content-Disposition: attachment; filename=\"#{file[:filename]}\"\n\n"
    content += "#{file[:content]}\n"
  end
  content += "--===============7530540225998998152==--\n"
  return Base64.encode64(content)
end

# checks that all states in 'instance_states' are in success_status
# raise an excpetion if all states or not in 'allowed_status'
def check_instances_have_state?(instance_states, success_status, allowed_states=nil, input=nil)
  success = 0
  failed = 0
    instance_states.each do |i|
      if i == success_status
        success += 1
      elsif not allowed_status.nil? and not allowed_states.include?(i)
        failed += 1
      end
    end

    if instance_states.length == failed
    raise "all instanes are in a failed state."
  else
      return instances.length == success
  end
end

