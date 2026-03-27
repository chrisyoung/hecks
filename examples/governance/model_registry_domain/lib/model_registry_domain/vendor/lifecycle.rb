module ModelRegistryDomain
  class Vendor
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "pending_review" unless defined?(DEFAULT)
      STATES = ["pending_review", "approved", "suspended"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "RegisterVendor" => "pending_review",
        "ApproveVendor" => { target: "approved", from: "pending_review" },
        "SuspendVendor" => { target: "suspended", from: "approved" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def pending_review?; @target == "pending_review"; end
      def approved?; @target == "approved"; end
      def suspended?; @target == "suspended"; end
    end
  end
end
