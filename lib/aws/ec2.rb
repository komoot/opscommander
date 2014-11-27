#autoscale

class Ec2

  attr_reader :verbose
  
  attr_reader :as_client = Aws::AutoScaling::Client.new

  def initialize(aws_connection=nil)
    @verbose = aws_connection.verbose
  end

  def find_autoscaling_group(name)
     group = 
     
     if groups
        return new AutoScalingGroup(self, group)
     end
  end

  def create_autoscale_group(as_config, launch_config)
     client = Aws::AutoScaling::Client.new
  end

end

class AutoScalingGroup

  attr_reader ec2

  def initialize(ec2, config)
    @ec2 = ec2
    @config = config
  end

  public

  def delete
  	@ec2.delete_autoscaling_group()
  end

end