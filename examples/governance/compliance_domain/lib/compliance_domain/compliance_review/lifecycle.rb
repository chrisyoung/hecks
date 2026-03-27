module ComplianceDomain
  class ComplianceReview
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "open" unless defined?(DEFAULT)
      STATES = ["open", "approved", "rejected", "changes_requested"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "OpenReview" => "open",
        "ApproveReview" => { target: "approved", from: ["open", "changes_requested"] },
        "RejectReview" => { target: "rejected", from: ["open", "changes_requested"] },
        "RequestChanges" => { target: "changes_requested", from: "open" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def open?; @target == "open"; end
      def approved?; @target == "approved"; end
      def rejected?; @target == "rejected"; end
      def changes_requested?; @target == "changes_requested"; end
    end
  end
end
