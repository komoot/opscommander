def deploy_app(ops, configuration, app_name)
  stack_name = configuration['stack']['name']
  stack = ops.find_stack(stack_name)
  stack.deploy_app(app_name)
end
