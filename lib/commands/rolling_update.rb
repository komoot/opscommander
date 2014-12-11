require_relative '../aws/ec2_autoscale.rb'

# elb-based rolling updates for ec2 autoscale groups
# based on the newer aws-sdk > 2

def rolling_update(aws_configuration, config, console)
    config = Hash.transform_keys_to_symbols(config)
    ec2 = Ec2Autoscale.new(aws_configuration)

    raise "no 'plain_ec2' section in config file" if not config[:plain_ec2]
    raise "no 'plain_ec2.autoscaling_group' section in config file" if not config[:plain_ec2][:autoscaling_group]
    raise "no 'plain_ec2.launch_config' section in config file" if not config[:plain_ec2][:launch_config]

    

    # for rolling updates, the existing and new autoscale groups and launch configs must not have the same names
    as_group_name_prefix = config[:plain_ec2][:autoscaling_group][:auto_scaling_group_name]
    prev_as_groups = ec2.find_autoscaling_group(as_group_name_prefix)
    if prev_as_groups.length == 0
      raise "No auto scaling group matching '#{as_group_name_prefix}' exists. Bootstrap one."
    elsif prev_as_groups.length > 1
      raise "#{prev_as_groups.length} scaling groups matching '#{as_group_name_prefix}' exist. Delete the unused one manually."
    else
      prev_as_group = prev_as_groups.first
    end

    as_group = config[:plain_ec2][:auto_scale_group]
    lc_group = config[:plain_ec2][:launch_config]
    id = Time.now.to_i.to_s
    as_group[:auto_scaling_group_name] += id
    lc_group[:launch_config_name] += id
    
    ec2.create(as_group, lc_group)
    
    ec2.wait_for_instances_in_elb(as_group)

end

#    if ec2.find_launch_config(config[:plain_ec2][:launch_config][:launch_config_name]).length > 0
#        raise "the launch config name '#{config[:plain_ec2][:launch_config][:launch_config_name]}' already exists."
#    end



