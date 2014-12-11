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
    if File.file?(File.expand_path(@filename))
      content = File.read(File.expand_path(@filename))
    else
      content = @filename
    end

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

# Handles optional events
class Events

  # executes the given events if existing
  # failing events cannot fail opscommander
  def self.execute(events)
    if events
      events.each do |event|
        e = event[:execute] || event['execute']
        if e
          if system(e)
            puts "Event sent."
          else
            puts "WARNING: command #{e} failed"
          end
        else
          puts "skipping unknown event type #{event}"
        end
      end
    end
  end
end

# recursively transforms keys to symbols
# Needed for Aws sdk >= 2.0
class Hash

  #take keys of hash and transform those to a symbols
  def self.transform_keys_to_symbols(value)
    if value.is_a?(Array)
      array = value.map{|x| x.is_a?(Hash) || x.is_a?(Array) ? Hash.transform_keys_to_symbols(x) : x}
      return array
    elsif value.is_a?(Hash)
      hash = value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
      return hash
    end
    return value
  end
  
end

