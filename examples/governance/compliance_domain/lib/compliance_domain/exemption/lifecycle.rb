module ComplianceDomain
  class Exemption
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "requested" unless defined?(DEFAULT)
      STATES = ["requested", "active", "revoked"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "RequestExemption" => "requested",
        "ApproveExemption" => { target: "active", from: "requested" },
        "RevokeExemption" => { target: "revoked", from: "active" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def requested?; @target == "requested"; end
      def active?; @target == "active"; end
      def revoked?; @target == "revoked"; end
    end
  end
end
