class AutoScalingSchedule

  def self.build(stack, config)
    new(stack.opsworks.client, config)
  end

  def parse_config(config)
    days = [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
    s = Hash[ days.collect { |d| [d, {}] } ]
    config.each do |day, from_to|
      split = from_to.split('-').map{|h| Integer(h)}
      range = split[0]..split[1]
      s[day.to_sym] = Hash[ range.collect{ |h| ["#{h}", 'on'] } ]
    end
    s
  end

  def initialize(client, config)
    @client = client
    @schedule = parse_config(config)
  end

  def apply(instance_ids) 
    instance_ids.each do |id|
      @client.set_time_based_auto_scaling(instance_id: id, auto_scaling_schedule: @schedule)
    end
  end

end
