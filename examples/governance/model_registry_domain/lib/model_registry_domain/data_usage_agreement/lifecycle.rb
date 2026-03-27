module ModelRegistryDomain
  class DataUsageAgreement
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "draft" unless defined?(DEFAULT)
      STATES = ["draft", "active", "revoked"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "CreateAgreement" => "draft",
        "ActivateAgreement" => { target: "active", from: "draft" },
        "RevokeAgreement" => { target: "revoked", from: "active" },
        "RenewAgreement" => { target: "active", from: ["active", "revoked"] },
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
      def revoked?; @target == "revoked"; end
    end
  end
end
