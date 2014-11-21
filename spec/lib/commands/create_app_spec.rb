require 'commands/create_app'

describe 'override_configuration' do
  
  def configuration
    return {'environment' => {'key1' => 'value1', 'key2' => 'value2'}}
  end

  one_update    = {'environment' => {'key1' => 'valuea', 'key2' => 'value2'}}
  two_updates   = {'environment' => {'key1' => 'valuea', 'key2' => 'valueb'}}
  one_addition  = {'environment' => {'key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3'}}

  it 'does nothing if defaults should be used' do
    override_configuration(configuration, nil).should eq(configuration)
    override_configuration(configuration, []).should eq(configuration)
  end

  it 'can override a single variable' do
    override_configuration(configuration, 'key1=valuea').should eq(one_update)
  end

  it 'can add a single variable' do
    override_configuration(configuration, 'key3=value3').should eq(one_addition)
  end

  it 'can override two variables' do
    override_configuration(configuration, 'key1=valuea,key2=valueb').should eq(two_updates)
    override_configuration(configuration, 'key1=valuea, key2=valueb').should eq(two_updates)
  end
end
