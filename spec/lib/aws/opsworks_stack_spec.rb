require 'aws/opsworks_stack'

describe 'opsworks_stack' do
  
  before(:each) do
    @client = double('client')
    @opsworks = double('opsworks', :client => @client)
    @stack = {:stack_id => 'stack-id-123'}
    @ec2_client = double('ec2_client')

    @sut = OpsWorksStack.new(@opsworks, @stack, @ec2_client)
  end

  it 'should handle secure environment variables' do
    client_argument = nil

    allow(@client).to receive(:describe_apps).and_return([])
    allow(@client).to receive(:create_app) { |arg| client_argument = arg }

    # Defining secure values is optional

    config = {
      'type' => 'other', 
      'app_source' => {'type' => 'other'},
      'environment' => {'tag1' => 'value1'}
    }

    @sut.create_app('test-app', config)

    expect(client_argument['environment'].length).to equal(1)
    expect(client_argument['environment'][0]['secure']).to equal(false)
    
    # If secure_environment is specified, the variable should be marked accordingly

    config = {
      'type' => 'other', 
      'app_source' => {'type' => 'other'},
      'environment' => {'tag1' => 'value1'},
      'secure_environment' => {'tag2' => 'value2'}
    }

    @sut.create_app('test-app', config)

    expect(client_argument['environment'].length).to equal(2)
    expect(client_argument['environment'][0]['secure']).to equal(false)
    expect(client_argument['environment'][1]['secure']).to equal(true)
  end

end


