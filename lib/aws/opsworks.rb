require 'json'
require_relative "opsworks_stack.rb"
require_relative "aws_configuration.rb"

# A wrapper class for {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html}.
class OpsWorks

  attr_accessor :verbose

  attr_reader :client

  attr_reader :elb_client

  def self.build(aws_connection)
    new(AWS::OpsWorks::Client.new({:region => 'us-east-1'}), AWS::ELB.new, aws_connection.verbose)
  end
  
  def initialize(opsworks_client, elb_client, verbose)
    @verbose = verbose
    @client = opsworks_client
    @elb_client = elb_client
  end

  public

  # Searches the stack with the given name
  #
  # @param stack_name [String] The stack name, e.g. "routing-alpha"
  # @return OpsWorksStack instance or nil
  def find_stack(stack_name)
    stacks = @client.describe_stacks()[:stacks]
    puts "#{stacks.length} stacks found in total." if @verbose
    if stacks.length > 0
      stack = stacks.select{|s| s[:name] == stack_name}.first
      if stack
        return OpsWorksStack.build(self, stack, @verbose)
      else
        return nil
      end
    end
  end

  # Create stack
  #
  # @param stack_config stack configuration
  # @return OpsWorksStack instance
  def create_stack(stack_config)
    # if custom_json is set convert it to string
    if stack_config.has_key?('custom_json')
      stack_config['custom_json'] = JSON.pretty_generate(stack_config['custom_json'])
    end
    if stack_config.has_key?('region') == false or stack_config['region'].nil?
      stack_config['region'] = AWS.config.region
    end
    stack = @client.create_stack(stack_config)
    return OpsWorksStack.build(self, stack, @verbose)
  end

  # Creates an instance with the given options hash.
  # See {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html#create_instance-instance_method}.
  # @param instance_options [Hash]
  # @return [String] The ID of the new instance.
  def create_instance(instance_options)
    options = instance_options.clone
    # we support 24/7 as parameter but amazon does not
    if options['auto_scaling_type'] == '24/7'
      options.delete('auto_scaling_type')
    end
    instance = @client.create_instance(options)
    puts "    Instance #{instance[:name]} \t #{instance_options['availability_zone']} #{instance_options['auto_scaling_type']}" if @verbose
    return instance[:instance_id]
  end

  def wait_for_instances_status(instance_ids, status, allowed_status=nil)
    Poll.poll(45*60, @verbose ? 5 : 15) do
      instances = @client.describe_instances({:instance_ids => instance_ids})[:instances]
      puts_instance_status(instances)
      success = check_instances_have_status?(instances, status, allowed_status)
    end
    puts "All instances are in status #{status}."
  end

  # Moves an ELB between two layers, which may be in different stacks.
  def move_elb(elb_name, from_layer, to_layer, mixed_state_duration=0)
    puts "Moving elb #{elb_name} ..."

    # First manually register instances, then switch in OpsWorks. 
    # Note that attaching an ELB will trigger a Configure event.
    
    to_layer.register_instances_with_elb(elb_name)

    puts "Allowing mixed state for #{mixed_state_duration} seconds ..."
    sleep(mixed_state_duration)

    if from_layer and from_layer.has_elb?(elb_name)
      from_layer.detach_elb(elb_name)
    end

    to_layer.attach_elb(elb_name)
  end

  # checks if the instances with the given ids have at the moment all the
  # given success_status
  # if allowed_status is set, the call raises an exception if the status is not successful
  # or any of the listed statuses.
  def check_instances_have_status?(instances, success_status, allowed_status=nil, input=nil)
    success = 0
    failed = 0
      instances.each do |i|
        if i[:status] == success_status
          success += 1
        elsif not allowed_status.nil? and not allowed_status.include?(i[:status])
          failed += 1
        end
      end

      if instances.length == failed
      raise "all instanes are in a failed state."
    else
      return instances.length == success
    end
  end

  def puts_instance_status(insts)
    if(insts.length > 0)
      puts " - " + insts.map { |i| "#{i[:hostname]} (#{i[:status]})" }.join(", ") 
    end
  end
 end
