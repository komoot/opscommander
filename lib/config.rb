require 'yaml'

require 'utils.rb'

module OpsWorksConfig

  def load(yaml_file, config)
    renderer = ErbHash.new(yaml_file, config)
    config = YAML.load(renderer.render())
  end

  def parse(yaml_file, config)
  	renderer = ErbHash.new(yaml_file, config)
  	renderer.render()
  end

  module_function :load, :parse

end

