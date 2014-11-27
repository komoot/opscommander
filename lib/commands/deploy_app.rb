def deploy_app(aws_connection, configuration, app_name)
  ops = OpsWorks.new(aws_connection)
  stack_name = configuration['stack']['name']
  stack = ops.find_stack(stack_name)
  stack.deploy_app(app_name)
end
