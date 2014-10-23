require 'pry'

class OpsWorksLayer

	def initialize(opsWorksStack, layer, verbose)
		@opsWorksStack = opsWorksStack
		@client = opsWorksStack.opsWorks.client #convenience
		@layer = layer
		@verbose = verbose
	end

	def create_instance(instance_config)
		copy = instance_config.clone
		copy['layer_ids'] = [layer_id]
		@opsWorksStack.create_instance(copy)
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
			return @opsWorksStack.stack_name + " :: " + name + " :: " + instance
		else
			return @opsWorksStack.stack_name + " :: " + name
		end
	end

	def delete
		get_instances.each do |i| @client.delete_instance({:instance_id => i[:instance_id]}) end
		@client.delete_layer({:layer_id => layer_id})
	end

	# sends a stop signal to all instances in this layer
	def send_stop
		disable_autoscaling()
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
	    		if @verbose
					puts "starting #{i[:name]} #{i[:auto_scaling_type]}"
				end
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
		puts "Attaching #{elb_name} to #{@opsWorksStack.stack_name}::#{name}" if @verbose
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
	    get_instances().each do |i|
	    	id=i[:ec2_instance_id]
	    	if id and i[:status] = "online"
				puts "Registering #{nice_name(i[:hostname])} (#{id}) with elb #{elb_name} ..." if @verbose
		    	elb.instances.register(id)
		    else
		    	puts "Skipping #{nice_name(i[:hostname])} (#{i[:status]})" if @verbose
		    end
	    end
	end	    

	# retrieves all instances in this layer.
	# optional filter
	# 
	def get_instances(filter={})
		@client.describe_instances({:layer_id => @layer[:layer_id]})[:instances]
	end

	private

	def disable_autoscaling
	    autoscaling_setup = @client.describe_load_based_auto_scaling({:layer_ids => [layer_id]})[:load_based_auto_scaling_configurations]
	    autoscaling_setup.each do |as|
			if as[:enable]
				as[:enable] = false
				@client.set_load_based_auto_scaling(as)
			end
		end
  	end

end