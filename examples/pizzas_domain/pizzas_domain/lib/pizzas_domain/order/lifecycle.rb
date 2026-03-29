module PizzasDomain
  class Order
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "pending" unless defined?(DEFAULT)
      STATES = ["pending", "cancelled"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "CancelOrder" => "cancelled",
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def pending?; @target == "pending"; end
      def cancelled?; @target == "cancelled"; end
    end
  end
end
