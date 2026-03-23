# Hecks::DSL::PolicyBuilder
#
# DSL builder for reactive policy definitions. Binds an event name to a
# trigger command, creating the wiring for event-driven workflows.
#
# Part of the DSL layer, nested under AggregateBuilder. Policies enable
# cross-context communication by reacting to events from any context.
#
#   builder = PolicyBuilder.new("NotifyKitchen")
#   builder.on "OrderPlaced"
#   builder.trigger "PrepareOrder"
#   builder.async true
#   policy = builder.build  # => #<Policy name="NotifyKitchen" async=true ...>
#
module Hecks
  module DSL
    class PolicyBuilder
      def initialize(name)
        @name = name
        @event_name = nil
        @trigger_command = nil
        @async = false
      end

      def on(event_name)
        @event_name = event_name
      end

      def trigger(command_name)
        @trigger_command = command_name
      end

      def async(flag = true)
        @async = flag
      end

      def build
        raise "Policy '#{@name}': missing 'on' (event name)" unless @event_name
        raise "Policy '#{@name}': missing 'trigger' (command name)" unless @trigger_command
        DomainModel::Behavior::Policy.new(
          name: @name,
          event_name: @event_name,
          trigger_command: @trigger_command,
          async: @async
        )
      end
    end
  end
end
