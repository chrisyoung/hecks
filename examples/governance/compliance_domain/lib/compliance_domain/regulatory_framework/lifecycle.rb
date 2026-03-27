module ComplianceDomain
  class RegulatoryFramework
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "draft" unless defined?(DEFAULT)
      STATES = ["draft", "active", "retired"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "RegisterFramework" => "draft",
        "ActivateFramework" => { target: "active", from: "draft" },
        "RetireFramework" => { target: "retired", from: "active" },
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
      def retired?; @target == "retired"; end
    end
  end
end
