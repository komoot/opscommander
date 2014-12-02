require_relative '../console.rb'

# Performs a blue-green deployment of a stack by cloning it.
# The deployment process is designed as failsafe and fault tolerant as possible. It can recover from broken earlier deploys.
#
def bluegreen(aws_connection, configuration, input, layer_filter=nil)
  ops = OpsWorks.new(aws_connection)
  stack_name = configuration['stack']['name']

  # is there still a blue stack?
  blue_stack = ops.find_stack(stack_name + "-blue")
  if blue_stack
    if input.choice("A blue stack still exists, maybe from an earlier failed deploy. Should we delete it first?", "Yn") == "y"
      blue_stack.delete
    else
      exit 1
    end
  end
  
  plain_stack = ops.find_stack(stack_name)
  green_stack = ops.find_stack(stack_name + "-green")
  
  if green_stack && plain_stack
    puts "Found both, #{stack_name} and #{stack_name}-green, cannot decide which is live. This is fatal. Manually delete the stack you don't need."
    exit 1
  elsif plain_stack
    plain_stack.rename_to(stack_name + "-green")
    green_stack = plain_stack
  elsif green_stack
    puts "Live stack already has the suffix '-green'."
  else
    puts "Stack #{stack_name} not found."
    exit 1
  end
  plain_stack = nil # not needed anymore, fail early

  # Configure a blue stack
  blue_configuration = {
    'stack' => configuration['stack'].clone,
    'layers' => configuration['layers'].clone
  }
  blue_configuration['stack']['name'] = blue_configuration['stack']['name'] + "-blue"

  # Validate deployment
  # Check if all layers can be switched
  puts "\nThe blue-green deployment strategy is 'elastic load balancer - based'. Validating blue configuration against green stack..."
  
  deployment_strategy = {}
  green_layers = green_stack.find_layers_by_name
  green_layer_elbs = green_stack.find_elbs

  blue_configuration['layers'].each do |blue_layer|
    elb_name = blue_layer['elb']
    green_layer = nil
    elb = nil
    if elb_name
      green_elb = green_layer_elbs.select{|e| e[:elastic_load_balancer_name] = elb_name}
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
      puts "WARN: green layer #{blue_layer['name']} does not exist or has no elb set."
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

  puts "\nThe following layers are affected by the update:"
  puts "  green layer \t elb \t blue layer"
  puts "  --------------------------------"
  deployment_strategy.each do |blue_name, hash|
    green_name = hash[:green_layer] ? hash[:green_layer].name : "--- "
    elb_name = hash[:elb] ? hash[:elb][:dns_name] : " (no elb) "
    puts "  #{green_name} \t #{elb_name} \t #{blue_name}"
  end
  exit unless input.choice("Do you want to continue", "Yn") == "y"


  # start the blue stack and but its layers into the deployment strategy
  blue_stack = bootstrap_stack(ops, blue_configuration, input, true, false)
  blue_stack.find_layers_by_name.each do |blue_layer|
    deployment_strategy[blue_layer.name][:blue_layer] = blue_layer
  end

  puts "\nAll instances in the blue stack are running."
  puts "You can now manually test the new instances."
  puts "In the next step you can switch between the blue and green stack."

  while true do
    continue = input.choice("Do you want to switch to the blue stack (yes) or remove the blue stack or abort?", "Yra")
    if continue == "a"
      exit
    elsif continue == "r"
      blue_stack.delete
      exit
    elsif continue == "y"
      deployment_strategy.each do |name, hash|
        elb_name = hash[:elb][:elastic_load_balancer_name]
        puts "Moving elb #{elb_name} ..."
        hash[:blue_layer].register_instances_with_elb(elb_name)
        if hash[:green_layer]
          if hash[:green_layer].has_elb?(elb_name)
            hash[:green_layer].detach_elb(elb_name)
          end
        end
        hash[:blue_layer].attach_elb(elb_name)

        ##TODO ops.execute_recipes_once layer, ["wanderwalter::newrelic_deploy_event"] # should be in config in future
      end
    end

    puts "Now, the blue stack is active. Let it run for a while..."
    continue = input.choice("Do you want to continue and delete the old green stack (y), switch back to green or abort", "Yga")
    if continue == "a"
      exit
    elsif continue == "g"
      deployment_strategy.each do |name, hash|
        puts "Moving elb #{elb_name} ..."
        hash[:blue_layer].detach_elb(elb_name)
        
        if hash[:green_layer]
          hash[:green_layer].attach_elb(elb_name)
        end

        ##TODO ops.execute_recipes_once layer, ["wanderwalter::newrelic_deploy_event"] # should be in config in future
      end

      puts "The green stack is now live again."
    elsif continue == "y"
      break
    end
  end

  puts "The blue stack is now live. Removing green stack and renaming blue stack...\n"
  # order is important!
  blue_stack.rename_to stack_name
  green_stack.delete
  puts "Deployment successfully finished!"
end
