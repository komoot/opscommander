#require "rubygems"
#require "bundler/setup"

require 'erb'
require_relative "../prompt.rb"
require_relative '../console.rb'

#
# Bootstraps a stack. (Currently designed for routing)
#
def bootstrap(ops, config, start_instances, input)
  stack_name = config['stack']['name']

  # check if stack already exists
  existing_stack = ops.find_stack stack_name
  if existing_stack
    if input.choice("A stack with the name #{stack_name} already exists. Do you want to delete it or abort?", "dA") == 'a'
      exit 1
    end
    existing_stack.delete
  end

  bootstrap_stack(ops, config, start_instances, input)

  if not start_instances
    puts "\nNot starting instances because --start was not given"
  end

end

# Creates a new stack from the given config. If a stack with the given name already
# exists, no exception is thrown and you have two stacks with the same name.
def bootstrap_stack(ops, config, input, start_instances, attach_elb=true)
  # create new stack
  puts "Creating stack #{config['stack']['name']} ..."
  stack = ops.create_stack(config['stack'])
  stack.grant_full_access   # grant ssh/sudo
  layers = []
  config['layers'].each do |l|
    layer_aws_config = l['config']
    aws_instances = l['instances']
    layer = stack.create_layer(layer_aws_config)
    aws_instances.each do |i|
      layer.create_instance(i)
    end
    layers.push(layer)
    if l['elb'] and attach_elb
      layer.attach_elb(l['elb'])
    end
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


