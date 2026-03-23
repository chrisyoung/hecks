# Hecks::DomainModel::Behavior::Policy
#
# Intermediate representation of a domain policy. Policies come in two forms:
# reactive policies that trigger a command in response to an event (cross-context
# communication), and guard policies that carry a block to validate commands.
#
# Part of the DomainModel IR layer. Built by PolicyBuilder (reactive) or
# AggregateBuilder (guard), consumed by generators and the Application layer.
# Use `reactive?` and `guard?` to distinguish the two forms.
#
#   # Reactive policy: event -> command
#   policy = Policy.new(name: "NotifyKitchen", event_name: "OrderPlaced",
#                       trigger_command: "PrepareOrder", async: true)
#   policy.reactive?  # => true
#   policy.guard?     # => false
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
      attr_reader :name, :event_name, :trigger_command, :async, :block

      def initialize(name:, event_name: nil, trigger_command: nil, async: false, block: nil)
        @name = name
        @event_name = event_name
        @trigger_command = trigger_command
        @async = async
        @block = block
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
