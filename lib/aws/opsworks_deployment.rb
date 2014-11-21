require 'pry'

class OpsWorksDeployment

  def initialize(stack, deployment)
    @stack = stack
    @client = @stack.opsworks.client 
    @app = app
  end

  def deployment_id
    @deployment[:deployment_id]
  end

  def get_status()
    d = @client.describe_deployments({
      :deployment_ids => [deployment_id]
    })[:deployments]

    if not d
      raise "Could not find deployment with id #{deployment_id}!"
    end

    return d[:status]
  end

end
