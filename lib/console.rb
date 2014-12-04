require 'highline/import'

#
# Wrapper around the highline input module
# 
# Adds a non-interactive feature (always yes flag)
class Console

  attr_reader :non_interactive
  attr_reader :verbose

  def initialize(non_interactive, verbose=false)
    @non_interactive = non_interactive
    @verbose = verbose
  end

  # Asks the user for his choice or returns the default choice if non_interactive is set.
  # message: text to print
  # choices: letters to choose from like "Yna"
  def choice(message, choices)
    default = default(choices)
    message = message + " [" + choices.split('').join('/') + "] ? "
    if non_interactive and default.nil?
      raise "--yes fails because '#{choices}' has no default value for question '#{message}'"
    elsif non_interactive
      puts message + default
      return default.downcase
    else
      value = ask(message, String) { |q| q.in = choices.downcase.split(""); }
      return value.downcase
    end
  end

  private

  def default(choices)
    choices.split("").each do |i|
        if i.upcase.eql?(i)
          return i.upcase
        end
      end
      return nil
  end
  
end
