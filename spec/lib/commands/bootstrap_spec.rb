require 'commands/bootstrap'

describe 'validate_load_based_auto_scaling_config' do
  
  it 'raises an error if auto scaling is enabled but no load instances are defined' do
    config = {
      'load_based_auto_scaling' => { 'default' => {} },
      'layers' => [{
        'instances' => [{'auto_scaling_type' => '24/7'}, {'auto_scaling_type' => '24/7'}],
        'load_based_auto_scaling' => {'enabled' => true, 'config' => 'default'}
      }]
    }

    expect { validate_load_based_auto_scaling_config(config, config['layers'].first) }.to raise_error
    config['layers'][0]['instances'][0]['auto_scaling_type'] = 'load'
    expect { validate_load_based_auto_scaling_config(config, config['layers'].first) }.to_not raise_error
  end

end

