require_relative '../console.rb'

# Performs a blue-green deployment of a stack by cloning it.
# The deployment process is designed as failsafe and fault tolerant as possible. It can recover from broken earlier deploys.
#
def bluegreen(ops, configuration, input, mixed_state_duration)
  stack_name = configuration['stack']['name']

  plain_stack = ops.find_stack(stack_name)
  green_stack = ops.find_stack(stack_name + "-green")

  if !green_stack and !plain_stack
    puts "Stack #{stack_name} not found."
    exit 1
  end
    
  if green_stack and plain_stack
    puts "Found both #{stack_name} and #{stack_name}-green, cannot decide which is live. This is fatal. Manually delete the stack you don't need."
    exit 1
  end 

  if plain_stack 
    if plain_stack.supports_bluegreen_deployment?(configuration) == false 
      raise "Stack #{stack_name} doesn't support blue-green deployment with the given configuration."
    end

    plain_stack.rename_to(stack_name + "-green")
    green_stack = plain_stack
    plain_stack = nil # not needed anymore, fail early
  elsif green_stack
    if green_stack.supports_bluegreen_deployment?(configuration) == false
      puts "Found stack #{stack_name}-green, but it doesn't support blue-green deployment with the given configuration."
      exit 1
    end

    puts "Green stack already called #{stack_name}-green"
  end


  # is there already a blue stack?
  blue_stack = ops.find_stack(stack_name + "-blue")
  if blue_stack
    if input.choice("A blue stack still exists, maybe from an earlier failed deploy. Should we delete it first?", "Yn") == "y"
      blue_stack.delete
    else
      exit 1
    end
  end

  blue_configuration = Marshal.load(Marshal.dump(configuration))

  blue_configuration['stack']['name'] = blue_configuration['stack']['name'] + "-blue"

  # Validate deployment
  # Check if all layers can be switched
  puts "\nThe blue-green deployment strategy is 'elastic load balancer - based'. Validating blue configuration against green stack..."
  
  deployment_strategy = {}
  green_layers = green_stack.find_layers_by_name
  green_layer_elbs = green_stack.find_elbs

  blue_configuration['layers'].each do |blue_layer|
    elb_name = blue_layer['elb'] ? blue_layer['elb']['name'] : nil
    if not elb_name
      # try to get the name of the ELB associated with this layer from OpsWorks
      elb_name = green_stack.find_elb_for_layer(blue_layer['config']['shortname'])
    end
    green_layer = nil
    elb = nil
    if elb_name
      green_elb = green_layer_elbs.select{|e| e[:elastic_load_balancer_name] == elb_name}
      if green_elb.length == 0
        puts "WARN: elb #{elb_name} not associated to any layer in green stack. Looking up in EC2..."
        ec2_elb = AWS::ELB.new.load_balancers[elb_name]
        elb = {:elastic_load_balancer_name => elb_name, :dns_name => ec2_elb.dns_name }
      else
        elb = green_elb[0]
        green_layer = green_layers.select{|g| g.layer_id == elb[:layer_id]}
        green_layer = green_layer.length > 0 ?  green_layer[0] : nil
      end
    else
      puts "WARN: green layer #{blue_layer['config']['name']} does not exist or has no elb set."
    end

    deployment_strategy[blue_layer['config']['name']] = { 
      :green_layer => green_layer,
      :elb => elb,
      :blue_layer => nil # set later
    }
  end

  if deployment_strategy.length == 0
    puts "No layer for deployment found. Exist"
    exit 1
  end

  printf "\nThe following layers are affected by the update:\n"
  printf "  %-20s %-60s blue layer\n", "green layer", "elb"
  printf "  ------------------------------------------------------------------------------------------------------\n"
  deployment_strategy.each do |blue_name, hash|
    green_name = hash[:green_layer] ? hash[:green_layer].name : "--- "
    elb_name = hash[:elb] ? hash[:elb][:dns_name] : " (no elb) "
    printf "  %-20s %-60s #{blue_name}\n", green_name, elb_name
  end
  exit unless input.choice("Do you want to continue", "Yn") == "y"


  # start the blue stack and put its layers into the deployment strategy
  blue_stack = bootstrap_stack(ops, blue_configuration, input, true, false)
  blue_stack.find_layers_by_name.each do |blue_layer|
    deployment_strategy[blue_layer.name][:blue_layer] = blue_layer
  end

  puts "\nAll instances in the blue stack are running."

  while true do
    continue = input.choice("The green stack is currently active. Do you want to switch to the blue stack (yes) or remove the blue stack or abort?", "Yra")
    if continue == "a"
      exit
    elsif continue == "r"
      blue_stack.delete
      exit
    elsif continue == "y"
      deployment_strategy.each do |name, hash|
        ops.move_elb(hash[:elb][:elastic_load_balancer_name], hash[:green_layer], hash[:blue_layer], mixed_state_duration)       
      end
    end

    puts "Now, the blue stack is active."
    Events.execute(configuration['events']['bluegreen_on_blue_active']) if configuration['events']

    continue = input.choice("Do you want to continue and delete the old green stack (y), switch back to green or abort", "Yga")
    if continue == "a"
      puts "Renaming green stack to '#{stack_name} and deleting blue stack ..."
      green_stack.rename_to stack_name
      blue_stack.delete
      exit
    elsif continue == "g"
      puts "Switching back to green stack..."
      deployment_strategy.each do |name, hash|
        ops.move_elb(hash[:elb][:elastic_load_balancer_name], hash[:blue_layer], hash[:green_layer])       
      end
      Events.execute(configuration['events']['bluegreen_on_revert_to_green']) if configuration['events']
      
    elsif continue == "y"
      # order is important!
      blue_stack.rename_to stack_name
      green_stack.delete
      break
    end
  end

  puts "Deployment finished!"
end
