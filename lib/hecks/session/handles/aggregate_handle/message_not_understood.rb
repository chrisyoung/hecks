# Hecks::Session::AggregateHandle::MessageNotUnderstood
#
# Smalltalk-inspired: unknown messages on an aggregate handle suggest
# creating a command. Instead of a bare NoMethodError, the user gets
# a helpful message with the exact code to create the command.
#
#   Cat.feed
#   # => Cat doesn't understand 'feed'.
#   #    Create it with: Cat.command("Feed") { attribute :name, String }
#
module Hecks
  class Session
    class AggregateHandle
      module MessageNotUnderstood
        def method_missing(method_name, *args, **kwargs, &block)
          cmd_name = Hecks::Utils.sanitize_constant(method_name.to_s)
          available = commands
          msg = "#{@name} doesn't understand '#{method_name}'."
          if available.any?
            msg += " Available commands: #{available.join(', ')}."
          end
          msg += "\n  Create it with: #{@name}.command(\"#{cmd_name}\") { attribute :name, String }"
          raise NoMethodError, msg
        end

        def respond_to_missing?(method_name, include_private = false)
          false
        end
      end
    end
  end
end
