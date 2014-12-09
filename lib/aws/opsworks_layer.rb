require 'poll'

class OpsWorksLayer
  def initialize(stack, layer, verbose)
    @stack = stack
    @client = stack.opsworks.client if stack   # Convenience
    @layer = layer
    @verbose = verbose
  end

  def create_instance(instance_config)
    copy = instance_config.clone
    copy['layer_ids'] = [layer_id]
    @stack.create_instance(copy)
  end

  def layer_id
    @layer[:layer_id]
  end

  def name
    if not @layer[:name]
          @layer = @client.describe_layers({:layer_ids => [layer_id]})[:layers][0]
      end
    @layer[:name]
  end

  def nice_name(instance=nil)
    if instance
      return @stack.stack_name + " :: " + name + " :: " + instance
    else
      return @stack.stack_name + " :: " + name
    end
  end

  def delete
    get_instances.each do |i| @client.delete_instance({:instance_id => i[:instance_id]}) end
    @client.delete_layer({:layer_id => layer_id})
  end

  # sends a stop signal to all instances in this layer
  def send_stop
    disable_load_based_auto_scaling()
    ids = []
      get_instances().each do |i|
        @client.stop_instance({:instance_id => i[:instance_id]})
        ids.push(i[:instance_id])
      end
      return ids
  end

  # sends a start signal to all permanent instances in this layer
  def send_start
    ids = []
    get_instances().each do |i|
      if not ['load', 'time'].include?(i[:auto_scaling_type])
        puts "starting #{i[:name]} #{i[:auto_scaling_type]}" if @verbose
        @client.start_instance({:instance_id => i[:instance_id]})
        ids.push(i[:instance_id])
      end
    end
    return ids
  end

  # Checks if the layer is associated with the given elb
  # @param elb_name [String]
  # @return [Boolean]
  def has_elb?(elb_name)
    elbs = @client.describe_elastic_load_balancers({:layer_ids => [layer_id]})[:elastic_load_balancers]
    elbs.length == 1 && elbs[0][:elastic_load_balancer_name] == elb_name
  end


  # Detaches an ELB from this layer.
  # OpsWorks itself takes care of deregistering instances.
  # @param elb_name [String]
  # @return void
  def detach_elb(elb_name)
    puts "Detaching #{elb_name} from #{nice_name}" if @verbose
    @client.detach_elastic_load_balancer({
      :elastic_load_balancer_name => elb_name,
      :layer_id => layer_id
    })
  end

  # Attaches an ELB to this layer.
  # OpsWorks itself takes care of registering instances.
  # @param elb_name [String]
  # @return void
  def attach_elb(elb_name)
    puts "Attaching #{elb_name} to #{nice_name}" if @verbose
    @client.attach_elastic_load_balancer({
      :elastic_load_balancer_name => elb_name,
      :layer_id => layer_id
    })
  end

  # Registers all currently existing instances in this layer with the elb
  # @param elb_name [String]
  # @return void
  def register_instances_with_elb(elb_name)
    elb = AWS::ELB.new.load_balancers[elb_name]
    instances = get_instances().select{|i| i[:ec2_instance_id]}
    instances.each do |i|
        if i[:status] = "online"
          puts "Registering #{nice_name(i[:hostname])} (#{i[:ec2_instance_id]}) with elb #{elb_name} ..." if @verbose
          elb.instances.register(i[:ec2_instance_id])
        else
          puts "Skipping #{nice_name(i[:hostname])} (#{i[:status]})" if @verbose
        end
      end

      ids_to_check = instances.map{ |i| {:instance_id => i[:ec2_instance_id]} }
      elb_client = Aws::ElasticLoadBalancing::Client.new
      Poll.poll(10 * 60, @verbose ? 5 : 15) do
        states = elb_client.describe_instance_health({
          :load_balancer_name => elb_name,
          :instances => ids_to_check
        })[:instance_states]
        
        in_service = states.select{|s| s.state == 'InService'}
        out_of_service = states.select{|s| s.state == 'OutOfService'}.first
        print " InService (#{in_service.size} / #{states.size}) " + (out_of_service.nil? ? "" : "[#{out_of_service.description}]") + "\r"
        in_service.size == states.size 
      end
    puts "\nAll instances InService"
  end     

  # retrieves all instances in this layer.
  # optional filter
  # 
  def get_instances(filter={})
    @client.describe_instances({:layer_id => @layer[:layer_id]})[:instances]
  end

  # Sets and enables a load-based auto scaling configuration.
  def enable_load_based_auto_scaling(config) 
    puts "Enabling load-based auto scaling for layer '#{name}'"
    @client.set_load_based_auto_scaling({
      :layer_id => layer_id,
      :enable => true,
      :up_scaling => config['up_scaling'],
      :down_scaling => config['down_scaling']
    })
  end

  private

  def disable_load_based_auto_scaling
      autoscaling_setup = @client.describe_load_based_auto_scaling({:layer_ids => [layer_id]})[:load_based_auto_scaling_configurations]
      autoscaling_setup.each do |as|
      if as[:enable]
        as[:enable] = false
        @client.set_load_based_auto_scaling(as)
      end
    end
    end

end
