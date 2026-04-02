# Hecks::DomainModel::Behavior::SagaTransition
#
# Intermediate representation of an event-driven transition in a saga
# (process manager). Each transition reacts to a named event and
# dispatches a command, optionally moving the saga to a new state.
#
# Part of the DomainModel IR layer. Built by SagaBuilder in the DSL,
# consumed by ProcessManager at runtime to drive event-based state
# machines.
#
#   transition = SagaTransition.new(
#     event: "PaymentReceived",
#     command: "ShipOrder",
#     from: "awaiting_payment",
#     to: "shipping"
#   )
#   transition.guarded?  # => true (has a from state)
#
module Hecks
  module DomainModel
    module Behavior
      class SagaTransition
        # @return [String] event name that triggers this transition
        attr_reader :event

        # @return [String] command to dispatch when event fires
        attr_reader :command

        # @return [String, nil] required current state (nil = any state)
        attr_reader :from

        # @return [String] target state after transition
        attr_reader :to

        # Creates a new SagaTransition IR node.
        #
        # @param event [String] the triggering event name
        # @param command [String] the command to dispatch
        # @param from [String, nil] required source state
        # @param to [String] target state after transition
        def initialize(event:, command:, from: nil, to:)
          @event = event.to_s
          @command = command.to_s
          @from = from&.to_s
          @to = to.to_s
        end

        # Whether this transition requires a specific source state.
        #
        # @return [Boolean]
        def guarded?
          !@from.nil?
        end
      end
    end
  end
end
