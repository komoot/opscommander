# A module for polling that supports timeouts. 
# @example
#   Poll.poll do
#     instances = <get instances>
#     all_instances_have_status? instances, "online"
#   end
#     
module Poll

  # Initiates a polling loop, executing the body
  # once every 15 seconds.
  # @param seconds [Integer] Timeout in seconds
  # @return void
  def poll(seconds=nil, delay=15) 
    seconds ||= 45*60 
    give_up_at = Time.now + seconds 
    failure = nil  # record the most recent failure

    while Time.now < give_up_at do
      result = yield
      return result if result
      sleep delay
    end
    msg ||= "polling failed after #{seconds} seconds" 
    raise msg
  end

  module_function :poll
  
end
