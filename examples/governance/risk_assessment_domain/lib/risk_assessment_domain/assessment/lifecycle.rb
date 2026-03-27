module RiskAssessmentDomain
  class Assessment
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "pending" unless defined?(DEFAULT)
      STATES = ["pending", "submitted", "rejected"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "InitiateAssessment" => "pending",
        "SubmitAssessment" => { target: "submitted", from: "pending" },
        "RejectAssessment" => { target: "rejected", from: ["pending", "submitted"] },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def pending?; @target == "pending"; end
      def submitted?; @target == "submitted"; end
      def rejected?; @target == "rejected"; end
    end
  end
end
