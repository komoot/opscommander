require 'erb'
require 'ostruct'

# http://stackoverflow.com/questions/8954706/render-an-erb-template-with-values-from-a-hash
class ErbHash < OpenStruct
  def render(template)
    ERB.new(template,0,'<>').result(binding)
  end
end