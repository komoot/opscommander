require 'erb'
require 'ostruct'

# http://stackoverflow.com/questions/8954706/render-an-erb-template-with-values-from-a-hash
class ErbHash < OpenStruct

  def initialize(filename, dictionary)
    super(dictionary)
    @filename = filename
  end

  # renders the template
  def render
    content = File.read(File.expand_path(@filename))
    t = ERB.new(content)
    t.result(binding)
  end

  # http://stackoverflow.com/questions/10236049/including-one-erb-file-into-another
  def render_file filename
    content = File.read(File.expand_path(filename, File.dirname(@filename)))
    t = ERB.new(content)
    t.result(binding)
  end

end