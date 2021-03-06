require 'aws-sdk-v1'

require_relative 'opsworks_layer.rb'
require_relative 'opsworks_app.rb'
require_relative 'opsworks_deployment.rb'

class OpsWorksStack

  attr_reader :opsworks

  def self.build(opsworks, stack, verbose=false) 
    new(opsworks, stack, AWS::EC2.new, verbose)
  end

  def initialize(opsworks, stack, ec2_client, verbose=false)
    @opsworks = opsworks
    # Convenience
    @client = opsworks.client
    @stack = stack
    @ec2_client = ec2_client
    @verbose = verbose
  end

  public

  # returns the stack id
  def stack_id
    @stack[:stack_id]
  end

  # returns the stack name
  def stack_name
    if not @stack[:name]
      @stack = @client.describe_stacks({:stack_ids => [stack_id]})[:stacks][0]
    end
    @stack[:name]
  end

  # updates the stack name
  def rename_to(new_name)
    old_name = stack_name
    instances_to_tag = @ec2_client.instances.with_tag('opsworks:stack', old_name)

    puts "Renaming #{stack_name} to #{new_name} ..."
    @client.update_stack({:stack_id => stack_id, :name => new_name})

    instances_to_tag.each do |i|
      instance_name = i.tags['opsworks:instance']
      i.tags.set({
        'opsworks:stack' => new_name,
        'Name' => "#{new_name} - #{instance_name}"
      })
    end

    #invalidate cached stack settings
    @stack = {:stack_id => stack_id}

  end

  # Grant ssh/sudo access to users based on their username.
  def grant_access(permissions)
    all_opsworks_arns = @client.describe_permissions({:stack_id => stack_id})[:permissions].collect{|p| p[:iam_user_arn]}

    permissions.each do |user, p|
      matching_arns = all_opsworks_arns.select{ |arn| arn.end_with? "user/#{user}" }

      if matching_arns.empty?
        puts "Warning! Could not find user '#{user}' in OpsWorks, so permissions could not be granted."
      else 
        arn = matching_arns.first
        puts "granting stack permissions for user #{arn} ..." if @verbose
        @client.set_permission({
          :stack_id => stack_id,
          :allow_ssh => p['ssh'],
          :allow_sudo => p['sudo'],
          :iam_user_arn => arn
        })
      end
    end
  end
  # Grant full ssh/sudo access to all opsworks users.
  # Used as fallback if there are no permissions defined in config.
  def grant_full_access
    permissions = @client.describe_permissions({:stack_id => stack_id})[:permissions]
    permissions.each do |perm|
      puts "granting stack permissions for user #{perm[:iam_user_arn]} ..." if @verbose
      @client.set_permission({
          :stack_id => stack_id,
          :allow_ssh => true,
          :allow_sudo => true,
          :iam_user_arn => perm[:iam_user_arn]
        })
    end
  end

  # Creates a layer with the given options hash.
  # See {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html#create_layer-instance_method}.
  # @param layer_options [Hash] 
  # @return [OpsworksLayer] An object representing the new layer
  def create_layer(layer_options)
    puts "Creating Layer \t#{stack_name} :: #{layer_options['name']}" if @verbose
    copy = layer_options.clone
    copy['stack_id'] = stack_id
    layer = @client.create_layer(copy)
    OpsWorksLayer.new(self, layer, @verbose)
  end

  # Creates an instance with the given options hash.
  # See {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html#create_instance-instance_method}.
  # @param instance_options [Hash]
  # @return [String] The ID of the new instance.
  def create_instance(instance_options)
    copy = instance_options.clone
    copy['stack_id'] = stack_id
    @opsworks.create_instance(copy)
  end

  # Returns an array of layer instances that exist in the
  # current OpsWorks stack and that begin with the given prefix.
  # @param prefix [String]
  # @return [Array] An array of layer names. 
  def find_layers_by_name(prefix = nil)
    layers = @client.describe_layers({:stack_id => stack_id()})[:layers]
    if prefix
      layers = layers.select {|l| l[:shortname].start_with? prefix }
    end

    layers.map{|l| OpsWorksLayer.new(self, l, @verbose)}
  end

  def find_layer_by_name(name) 
    layers = @client.describe_layers({:stack_id => stack_id()})[:layers]
    layers = layers.select{|l| l[:shortname].eql? name}
    if layers.empty?
      raise "Couldn't find layer with name #{name}!"
    end
    OpsWorksLayer.new(self, layers.first, @verbose)
  end

  #
  # Returns all elastic load balancers registered with layers in this stack
  def find_elbs
    @client.describe_elastic_load_balancers({:stack_id => stack_id})[:elastic_load_balancers]
  end

  # Clones the current stack
  # See http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html#clone_stack-instance_method
  def clone_stack(new_stack_name)
    stack = @opsworks.client.clone_stack({
      :source_stack_id => stack_id,
      :name => new_stack_name
      })

    stack = OpsWorksStack.build(@opsworks, stack)
    puts "cloned stack #{stack[:stack_id]}" if @verbose
    return stack
  end

  # deletes the entire stack. This method is potentially dangerous!
  def delete
    delete_layers_by_name()
    delete_apps()
    @client.delete_stack({:stack_id => stack_id})
    puts "Deleted #{stack_name}."
  end

  # Stops all instances of all layers given in the layer_names array,
  # both 24/7 and autoscaling ones. Waits for all instances to stop before returning.
  # Disables autoscaling.
  # @param layer_names [Array]
  # @return void
  def delete_layers_by_name(prefix = nil)
    layers = find_layers_by_name(prefix)

    puts "Deleting layers in #{stack_name}. Waiting for all instance(s) to stop ..."    
    layers.each do |l| l.send_stop end
 
    Poll.poll(10 * 60, @verbose ? 5 : 15) do
      instances = layers.map{|l| l.get_instances}.flatten
      print_current_instance_status(instances)
      all_instances_have_status?(instances, "stopped")
    end
    puts "All instances in #{stack_name} stopped."

    layers.each do |l| l.delete() end
    puts "All layers in #{stack_name} deleted."
  end

  # Create an app.
  def create_app(name, config)
    puts "creating app #{name} ..." if @verbose
    begin 
      existing_app = get_app(name)
      existing_app.delete()
      puts "Deleted existing app '#{name}'."
    rescue  
      # no app exists with the same name
    end

    # remap environment from our configuration style to OpsWorks' 
    
    options = {}

    collect = lambda do |env_config, secure|
      if env_config
        return env_config.collect{ |k, v| {'key' => "#{k}", 'value' => "#{v}", 'secure' => secure} }
      else
        return []
      end
    end

    options['environment'] = collect.call(config['environment'], false)
    options['environment'].concat(collect.call(config['secure_environment'], true))
    options['type'] = config['type']
    options['name'] = name
    options['stack_id'] = stack_id
    options['data_sources'] = [] if not config['data_sources']

    app = @client.create_app(options)
    puts "Created app '#{name}'."
    OpsWorksApp.new(self, app)
  end

  # Retrieves an app by name.
  def get_app(name)
    apps = @client.describe_apps({:stack_id => stack_id})[:apps]
    apps = apps.select {|a| a[:name].eql? name}

    if apps.length == 0 
      raise "Could not find app called \"#{name}\"!"
    end
    
    OpsWorksApp.new(self, apps.first)
  end

  # Deletes all apps in the stack
  def delete_apps()
    apps = @client.describe_apps({:stack_id => stack_id})[:apps]
    apps.each do |a|
      @client.delete_app({:app_id => a[:app_id]})
      puts "App '#{a[:name]}' deleted."
    end
  end

  # Deploys an app. 
  def deploy_app(name)
    app = get_app(name)

    online_instances = @client.describe_instances({:stack_id => stack_id})[:instances].select{|i| i[:status] == 'online'}
    if online_instances.empty?
      raise "No online instances."
    end

    instance_ids = online_instances.reduce([]) do |ids, i|
      ids << i[:instance_id]
    end

    deployment = OpsWorksDeployment.new(self, app.deploy(instance_ids))
    status = 'running'

    Poll.poll(20 * 60, @verbose ? 5 : 15) do
      status = deployment.get_status
      puts "Deployment status: #{status}"
      deployment_finished?(status)
    end

    if (status != 'successful') 
      raise "Deployment unsuccesful!"
    end

    puts "Deployment successful."
  end

  # Returns the name of the ELB associated with the given layer, or nil
  def find_elb_for_layer(layer_name) 
    layer = find_layer_by_name(layer_name)
    opsworks_elbs = @client.describe_elastic_load_balancers({:layer_ids => [layer.layer_id]})[:elastic_load_balancers]

    if opsworks_elbs.empty?
      return nil
    end

    opsworks_elbs.first[:elastic_load_balancer_name]
  end

  # Creates an elb using this stack's region and vpc settings
  def create_elb(config)
    lb_placeholder = @opsworks.elb_client.load_balancers[config['name']]
    if not lb_placeholder.exists?
      puts "creating new elb #{config['name']}" if @verbose
      new_config = {:listeners => config['listeners']}
      new_config[:availability_zones] = config['availability_zones'] if config['availability_zones']
      new_config[:subnets] = config['subnets'] if config['subnets']
      new_config[:security_groups] = config['security_groups'] if config['security_groups']
      new_config[:scheme] = config['scheme'] if config['scheme']
      puts new_config
      @opsworks.elb_client.load_balancers.create(config['name'], new_config)
      lb_placeholder = @opsworks.elb_client.load_balancers[config['name']]
      if not lb_placeholder.exists?
        raise "could not find elb #{config['name']} after creation"
      end
    else
      puts "skipping existing elb #{config['name']}" if @verbose
    end

    lb_placeholder.configure_health_check(config['health_check'])
  end

  # Returns true if the stack supports blue-green deployment with the given configuration. 
  # There are three supported modes:
  #  - manual (nothing defined in YAML, layers need to have ELBs defined manually)
  #  - named (ELB is named in YAML and must exist in EC2)
  #  - automatic (ELB is named and specified in YAML, will be created if it doesn't exist)
  def supports_bluegreen_deployment?(config)
    config['layers'].each do |layer| 
      if not layer['elb'] 
        # manual
        return find_elb_for_layer(layer['config']['shortname']) != nil
      else
        # named or automatic
        return layer['elb']['name'].length > 0
      end
    end
  end

  def find_all_layers
    return find_layers_by_name()
  end

  def enable_load_based_auto_scaling
    layers = find_all_layers()
    layers.each do |layer|
      layer.enable_load_based_auto_scaling
    end
  end

  private

  def deployment_finished?(status)
    return status == 'successful' || status == 'failed'
  end

  def all_instances_have_status?(instances, status)
    filtered = instances.select {|i| i[:status] == status}
    instances.length == filtered.length
  end

  def print_current_instance_status(insts)
    puts " - " + insts.map { |i| "#{i[:hostname]} (#{i[:status]})" }.join(", ") 
  end

end


