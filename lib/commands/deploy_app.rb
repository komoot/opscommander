def deploy_app(aws_connection, configuration, app_name)
  ops = OpsWorks.new(aws_connection)
  stack_name = configuration['stack']['name']
  stack = ops.find_stack(stack_name)
  if not stack
  	stack = ops.find_stack(stack_name + "-green")
  	if stack
  	   puts "Could not find stack '#{stack_name}' but '#{stack_name}-green' exists from an earlier bluegreen deployment."
  	else
       raise "Could not find stack '#{stack_name}'"
    end
  end
  stack.deploy_app(app_name)
end
