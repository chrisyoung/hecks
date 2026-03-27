module OperationsDomain
  class Incident
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "reported" unless defined?(DEFAULT)
      STATES = ["reported", "investigating", "mitigating", "resolved", "closed"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "ReportIncident" => "reported",
        "InvestigateIncident" => { target: "investigating", from: "reported" },
        "MitigateIncident" => { target: "mitigating", from: "investigating" },
        "ResolveIncident" => { target: "resolved", from: ["investigating", "mitigating"] },
        "CloseIncident" => { target: "closed", from: "resolved" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def reported?; @target == "reported"; end
      def investigating?; @target == "investigating"; end
      def mitigating?; @target == "mitigating"; end
      def resolved?; @target == "resolved"; end
      def closed?; @target == "closed"; end
    end
  end
end
