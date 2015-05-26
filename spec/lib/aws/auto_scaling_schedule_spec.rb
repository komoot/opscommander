require 'aws/auto_scaling_schedule'

describe 'auto_scaling_schedule' do
  
  before(:each) do
    @client = double('client')
    @client_argument = nil
    allow(@client).to receive(:set_time_based_auto_scaling) { |arg| @client_argument = arg }
  end

  it 'sets the instance id' do
    schedule = AutoScalingSchedule.new(@client, {})
    schedule.apply(['some-instance'])
    expect(@client_argument[:instance_id]).to eq('some-instance')
  end

  it 'disables scaling if there is no config' do
    schedule = AutoScalingSchedule.new(@client, {})
    schedule.apply(['some-instance'])

    days = [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
    days.each do |d|
      expect(@client_argument[:auto_scaling_schedule][d]).to eq({})
    end
  end

  it 'parses from-to config' do
    config = {'sunday' => '9-12'}
    schedule = AutoScalingSchedule.new(@client, config)
    schedule.apply(['some-instance'])

    empty_days = [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday]
    empty_days.each do |d|
      expect(@client_argument[:auto_scaling_schedule][d]).to eq({})
    end

    expect(@client_argument[:auto_scaling_schedule][:sunday]).to eq({'9' => 'on', '10' => 'on', '11' => 'on', '12' => 'on'})
  end

end

