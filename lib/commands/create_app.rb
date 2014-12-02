def create_app(aws_connection, configuration, app_name)
  ops = OpsWorks.new(aws_connection)
  stack_name = configuration['stack']['name']
  stack = ops.find_stack(stack_name)
  stack.create_app(app_name, configuration)
end

