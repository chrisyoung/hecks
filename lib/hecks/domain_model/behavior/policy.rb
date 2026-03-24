# Hecks::DomainModel::Behavior::Policy
#
# Intermediate representation of a domain policy. Policies come in two forms:
# reactive policies that trigger a command in response to an event (cross-context
# communication), and guard policies that carry a block to validate commands.
# Reactive policies support an optional `condition` block that receives the event
# and must return true for the policy to fire.
#
# Part of the DomainModel IR layer. Built by PolicyBuilder (reactive) or
# AggregateBuilder (guard), consumed by generators and the Application layer.
# Use `reactive?` and `guard?` to distinguish the two forms.
#
#   # Reactive policy: event -> command (conditional)
#   policy = Policy.new(name: "FraudAlert", event_name: "Withdrew",
#                       trigger_command: "FlagSuspicious",
#                       condition: ->(event) { event.amount > 10_000 })
#   policy.reactive?   # => true
#   policy.condition   # => #<Proc ...>
#
#   # Guard policy: block validates a command
#   guard = Policy.new(name: "MustBeAdmin", block: ->(cmd) { cmd.role == "admin" })
#   guard.guard?      # => true
#   guard.reactive?   # => false
#
module Hecks
  module DomainModel
    module Behavior
    class Policy
      attr_reader :name, :event_name, :trigger_command, :async, :block, :attribute_map, :condition

      def initialize(name:, event_name: nil, trigger_command: nil, async: false, block: nil, attribute_map: {}, condition: nil)
        @name = name
        @event_name = event_name
        @trigger_command = trigger_command
        @async = async
        @block = block
        @attribute_map = attribute_map
        @condition = condition
      end

      def guard?
        block != nil
      end

      def reactive?
        event_name != nil
      end
    end
    end
  end
end
