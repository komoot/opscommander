require "aws-sdk"
require_relative '../poll.rb'
require_relative 'opsworks_layer.rb'

class OpsWorksStack

  attr_reader :opsworks

  def initialize(opsworks, stack, verbose)
    @client = opsworks.client
    @opsworks = opsworks
    @stack = stack
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
    puts "Renaming #{stack_name} to #{new_name} ..."
    @client.update_stack({:stack_id => stack_id, :name => new_name})

    #invalidate cached stack settings
    @stack = {:stack_id => stack_id}
  end

  # Grant full ssh/sudo access to all opsworks users
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
  # @return [String] The ID of the new layer.
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

    stack = OpsWorksStack.new(@opsworks, stack)
    puts "cloned stack #{stack[:stack_id]}" if @verbose
    return stack
  end

  # deletes the entire stack. This method is potentially dangerous!
  def delete
    delete_layers_by_name()
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

  # Creates a custom app. Use this as a proxy for triggering deployments.
  def create_app(name, environment_variables)
    environment = environment_variables.collect{ |k, v|
      {:key => k, :value => v}
    }

    options = {
      :stack_id => stack_id,
      :type => "other",
      :name => name,
      :environment => environment
    }

    app = @client.create_app(options)
    OpsWorksApp.new(self, app)
  end

  # Retrieves an app by name.
  def get_app(name)
    apps = @client.describe_apps({:stack_id => stack_id})[:apps]
    app = apps.select {|a| a[:name].eql? name}

    if apps.length == 0 
      raise "Could not find app called \"#{name}\"!"
    end
    
    OpsWorksApp.new(self, apps.first)
  end

  private

  def all_instances_have_status?(instances, status)
    filtered = instances.select {|i| i[:status] == status}
    instances.length == filtered.length
  end

  def print_current_instance_status(insts)
    puts " - " + insts.map { |i| "#{i[:hostname]} (#{i[:status]})" }.join(", ") 
  end

end


