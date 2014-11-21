require 'pry'

class OpsWorksApp

  def initialize(stack, app)
    @stack = stack
    @client = @stack.opsworks.client 
    @app = app
  end

  def app_id
    @app[:app_id]
  end

  def delete
    @client.delete_app({:app_id => app_id})
  end

  def deploy(instance_ids)
    deployment = @client.create_deployment({
      :stack_id => @stack.stack_id,
      :instance_ids => instance_ids,
      :app_id => app_id,
      :command => {:name => 'deploy'},
      :comment => "Launched by #{ENV['USER']} using Opscommander"
    })

    puts "Deployment triggered."
    return deployment
  end

end
