module ComplianceDomain
  class GovernancePolicy
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "draft" unless defined?(DEFAULT)
      STATES = ["draft", "active", "suspended", "retired"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "CreatePolicy" => "draft",
        "ActivatePolicy" => { target: "active", from: "draft" },
        "SuspendPolicy" => { target: "suspended", from: "active" },
        "RetirePolicy" => { target: "retired", from: ["active", "suspended"] },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def draft?; @target == "draft"; end
      def active?; @target == "active"; end
      def suspended?; @target == "suspended"; end
      def retired?; @target == "retired"; end
    end
  end
end
