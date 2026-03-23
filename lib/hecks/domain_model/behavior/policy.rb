# Hecks::DomainModel::Behavior::Policy
#
# Intermediate representation of a reactive policy -- a rule that triggers
# a command in response to a domain event. Policies are the approved
# mechanism for cross-context communication in Hecks.
#
# Part of the DomainModel IR layer. Built by PolicyBuilder and consumed by
# PolicyGenerator and the Playground/Application for wiring event reactions.
#
#   policy = Policy.new(
#     name: "NotifyKitchen",
#     event_name: "OrderPlaced",
#     trigger_command: "PrepareOrder",
#     async: true
#   )
#   policy.event_name       # => "OrderPlaced"
#   policy.trigger_command  # => "PrepareOrder"
#   policy.async            # => true
#
module Hecks
  module DomainModel
    module Behavior
    class Policy
      attr_reader :name, :event_name, :trigger_command, :async

      def initialize(name:, event_name:, trigger_command:, async: false)
        @name = name
        @event_name = event_name
        @trigger_command = trigger_command
        @async = async
      end
    end
    end
  end
end
