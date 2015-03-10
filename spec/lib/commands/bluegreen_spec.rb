require 'commands/bluegreen'

describe 'bluegreen' do
  
  context 'without explicit ELB configuration' do
    before(:each) do
      @config = {
        'stack' => {'name' => 'Test stack'},
        'layers' => [{
          'config' => {'name' => 'Test layer'},
          'elb' => nil
        }]
      }

      @stack = double('stack')

      @ops = double('ops')
      allow(@ops).to receive(:find_stack).with('Test stack-blue').and_return(false)
      allow(@ops).to receive(:find_stack).with('Test stack-green').and_return(false)
      allow(@ops).to receive(:find_stack).with('Test stack').and_return(@stack)
    end
      
    it 'Should fail if no manually configured ELB is found' do
      expect(@stack).to receive(:supports_bluegreen_deployment?).and_return(false)
      expect(@stack).to_not receive(:rename_to)
      expect { bluegreen(@ops, @config, nil, 0) }.to raise_error(RuntimeError, /doesn't support blue-green deployment/)
    end

  end

end

