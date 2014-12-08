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
