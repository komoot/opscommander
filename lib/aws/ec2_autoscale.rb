require_relative "aws_configuration.rb"

# A wrapper class for {http://docs.aws.amazon.com/sdkforruby/api/frames.html}.
class Ec2Autoscale

  attr_accessor :verbose

  attr_reader :client

  attr_reader :elb_client
  
  attr_reader :as_client

  def initialize(aws_connection)
    @verbose = aws_connection.verbose
    @elb_client = Aws::ELB::Client.new
    @as_client = Aws::AutoScaling::Client.new
  end

  public

  # returns the autoscaling group with the given name or nil
  def find_autoscaling_groups(name_prefix)
  	groups = @as_client.as_client.describe_auto_scaling_groups()[:auto_scaling_groups]
  	return groups.select{|a| a[:auto_scaling_group_name].start_with?(name_prefix)}
  end

  # returns the launch config with the given name or nil
  def find_launch_config(name)
    l = @as_client.as_client.describe_launch_configurations()[:launch_configurations]
    return l.select{|a| a[:launch_configuration_name].start_with?(name_prefix)}
  end

  # creates the given autoscale group and launch config
  def create(as_config, launch_config, start_instances=true)
    puts "creating launch-config '#{launch_config[:launch_configuration_name]}' ..." if @verbose
    launch_config[:user_data] = parse_userdata(launch_config[:user_data])
  	@as_client.create_launch_configuration(lconfig)
	
    puts "creating autoscaling-group '#{as_config[:auto_scaling_group_name]}'..." if @verbose
    if not start_instances
        as_config = as_config.clone # shallow copy
        as_config[:min_size] = 0
        as_config[:max_size] = 0
        as_config[:desired_capacity] = 0
    end
    @as_client.create_auto_scaling_group(as_config)
  end

  def wait_for_instances_in_elb(as_config)
    
    if instances.length == 0
        puts "(warning) no instances in autoscaling_group!"
        return false
    end

    instances = nil
    puts "waiting for #{instances.length} instances in '#{as_config[:auto_scaling_group_name]}' to boot ..."
    Poll.poll(45*60, @verbose ? 5 : 15) do
        instances = as_client.describe_auto_scaling_groups({
            :auto_scaling_group_names => [as_config[:auto_scaling_group_name]]
        })[:auto_scaling_groups].first[:instances]

        success = false
        if instances.length == 0
            print " waiting for instances ...\r"
        else
            print "ec2 state: " + instances.map { |i| "(#{i[:instance_id]} #{i[:lifecycle_state]}" }.join(" ") + "\r"
            success = check_instances_have_state?(instances.map{|i| i[:lifecycle_state]}, "InService")
        end
        success
    end

    as_config[:load_balancer_names].each do |elb|

    puts "waiting for instances to be healty in elb '#{elb}'..."
    Poll.poll(45*60, @verbose ? 5 : 15) do
        health_states = elb_client.describe_instance_health({
                :load_balancer_name => elb,
                :instances =>  instances.map{ |i| {:instance_id => i[:instance_id]} }
            })[:instance_states]

        success = false
        if health_states.length == 0
          print " no instances in elb, yet...\r"
        else
          print "elb state: " + health_states.map { |i| "(#{i[:instance_id]} #{i[:state]}" }.join(" ") + "\r"
          success = check_instances_have_state?(instances.map{|i| i[:state]}, "InService")
        end
        success
      end
    end
    puts "All instances are InService."
  end

  private

  # takes a list of user data files and creates a base64 encoded multipart message
  def self.parse_userdata(files)
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
end