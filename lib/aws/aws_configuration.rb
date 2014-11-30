require "aws-sdk-v1"
require "aws-sdk"
require 'json'

#
# encapsulates the AWS configuration (region, the user+credentials) and a verbose flag
#
class AwsConfiguration

  attr_accessor :verbose

  attr_reader :client

  def initialize(region='eu-west-1', verbose=false)
    @verbose = verbose
    
    # static region configuration
    AWS.config({:region => region})

    whoami if @verbose
  end

  public

  # Print the current aws authentication data
  def whoami
    client = AWS::IAM::Client.new
    user = client.get_user()[:user]
    puts "Current AWS user name is #{user[:user_name]} with access key #{user[:user_id]}"
    puts "Connected to region #{AWS.config.region}"
  end

end