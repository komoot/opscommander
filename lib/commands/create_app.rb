def create_app(ops, configuration, app_name, variables)
  stack_name = configuration['stack']['name']
  stack = ops.find_stack(stack_name)
  config = override_configuration(configuration['apps'][app_name], variables)
  stack.create_app(app_name, config)
end

def override_configuration(app_config, variables)
  if not variables or variables.empty? 
    return app_config
  end

  variables.split(',').each do |v|
    parts = v.strip.split('=')
    app_config['environment'][parts[0]] = parts[1]
  end

  return app_config
end
