# run an OpsWorks instance using vagrant

require 'erb'
require 'fileutils'
require 'json'

require_relative '../utils.rb'
require_relative '../console.rb'

#
# Bootstraps a stack. (Currently designed for routing)
#
def vagrant_test(config)

  stack_name = config['stack']['name']
  layers = config['layers']
  layers.each do |l|
  	layer_config = l['config']
  	instance = l['instances'].first

  	test_directory = "/tmp/#{stack_name}/#{layer_config['shortname']}/"
  	prepare_directory(test_directory)
  	puts "testing #{stack_name} :: #{layer_config['shortname']} in #{test_directory}"

  	# we want to run all setup and deploy recipes
  	vagrant_config = {:name => "#{layer_config['shortname']}"}
  	stack_configuration = {
  		:opsworks => {
  			:stack => {
  				:name => stack_name
  			},
  			:instance => {
  				:layers => [layer_config['shortname']]
  			}
  		}
  	}
  	
  	if config['stack'].has_key? 'custom_json'
  		stack_configuration = stack_configuration.merge(config['stack']['custom_json'])
  	end

  	# set up iam role - extract last part of arn
  	role_arn = config['stack']['default_instance_profile_arn']
  	puts "Creating temporary credentials for instance role " + role_arn[/\/(.*)/,1]

  	assumed_role = AWS::STS.new.assume_role({:role_session_name => 'temporary', :role_arn => role_arn.sub!('instance-profile', 'role')})
  	stack_configuration[:aws] = {
  		:region => config['stack']['region'],
  		:access_key_id => assumed_role[:credentials][:access_key_id],
  		:secret_access_key => assumed_role[:credentials][:secret_access_key],
  		:session_token => assumed_role[:credentials][:session_token]
  	}

  	vagrant_config[:custom_json] = stack_configuration.inspect
  	if layer_config.has_key? 'custom_recipes'
  		recipes = layer_config['custom_recipes']['setup'] + layer_config['custom_recipes']['deploy']
  	  	vagrant_config[:run_list] = recipes.map{|x| "\"" + x + "\"" }.join(',')
  	end
  	save_config(vagrant_config, test_directory + "Vagrantfile")

  	download_archive(config['stack']['custom_cookbooks_source'], test_directory)

  	system("cd #{test_directory} && vagrant up && vagrant destroy -f")
  end
end

# prepares a clean directory
def prepare_directory(name)
	if Dir.exists? name
		FileUtils.rm_rf name
	end
  	FileUtils.mkdir_p name
end


def save_config(config, target)
  # read config json file
  file = File.open(File.join(__dir__, 'vagrant.erb'), "rb")
  renderer = ErbHash.new(config)
  result = renderer.render(file.read)

  target_file = File.open(target, "w")
  target_file.write(result)
  target_file.close
end

def download_archive(cookbooks_source, target)
	if cookbooks_source['type'] == 's3'
		url = cookbooks_source['url']
		url = url.gsub(/^http.:\/\/.*amazonaws.com\//,'s3://')
		# TODO how to ret rid of the region
		puts_system("aws s3 cp --region eu-west-1 #{url} #{target}archive.tar.gz")
		puts_system("cd #{target} && tar -xzf archive.tar.gz && mv cookbooks/* .")
	else
		puts "download source type #{cookbooks_source['type']} not yet supported"
		exit 1
	end
end

def puts_system(cmd)
	puts "> #{cmd}"
	if not system cmd
		exit 1
	end
end
