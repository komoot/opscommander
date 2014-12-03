require 'config'

describe 'config' do

  it 'supports default values in YAML config file' do
    tpl = 'key: <%= value || \'value\' %>'
    
    config = OpsWorksConfig.load(tpl, {})
    expect(config['key']).to eq('value')

    config = OpsWorksConfig.load(tpl, {'value' => 'other'})
    expect(config['key']).to eq('other')
  end 
end
