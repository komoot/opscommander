require 'pry'

class OpsWorksApp

  def initialize(stack, app)
    @stack = stack
    @client = @stack.opsworks.client 
    @app = app
  end

  def delete
    @client.delete_app({:app_id => @app[:app_id]})
  end

  # todo: deploy

end
