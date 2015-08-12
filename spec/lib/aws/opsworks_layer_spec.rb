require 'aws/opsworks_stack'
require 'aws/opsworks_layer'

describe 'opsworks_layer' do

  before(:each) do
    @client = double('client')
    opsworks = double('opsworks', :client => @client)
    stack = OpsWorksStack.new(opsworks, {}, double('ec2_client'))
    @layer = OpsWorksLayer.new(stack, {:id => 'test-layer'})
  end

  it 'should find running load instances' do
    allow(@client).to receive(:describe_instances).and_return(
      {:instances => 
        [{:status => 'online'},
         {:auto_scaling_type => 'load', :status => 'stopped'},
         {:auto_scaling_type => 'load', :status => 'online'},
         {:auto_scaling_type => 'load', :status => 'running_setup'}]}
    )

    expect(@layer.get_running_load_instances().length).to equal(2)
  end
end

  

