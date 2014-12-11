#
# restarts service(s) (with downtime)
def restart(config)
    raise "only work with 'plain_ec2'" if not config[:plain_ec2]
    config = config[:plain_ec2]

    as_client = Aws::AutoScaling::Client.new
    ec2_client = Aws::Ec2::Client.new

    existing_group = as_client.describe_auto_scaling_groups({
        :auto_scaling_group_names => [config[:autoscaling_group][:auto_scaling_group_name]]
     })[:auto_scaling_groups].first

    raise "no such autoscaling group: '#{config[:autoscaling_group][:auto_scaling_group_name]}'." if not existing_group

    existing_group[:instances].each do |as_instance|
    	id = as_instance[:instance_id]
    	local_ip = ec2. ... id
    	cmd = config[:deployment_strategies][:restart]
    	shell cmd replace ip
    	puts "restarted instance #{id}"
    end


end