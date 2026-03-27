module IdentityDomain
  class Stakeholder
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "active" unless defined?(DEFAULT)
      STATES = ["active", "deactivated"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "RegisterStakeholder" => "active",
        "DeactivateStakeholder" => { target: "deactivated", from: "active" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def active?; @target == "active"; end
      def deactivated?; @target == "deactivated"; end
    end
  end
end
