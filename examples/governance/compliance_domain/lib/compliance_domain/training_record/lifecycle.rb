module ComplianceDomain
  class TrainingRecord
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "assigned" unless defined?(DEFAULT)
      STATES = ["assigned", "completed"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "AssignTraining" => "assigned",
        "CompleteTraining" => { target: "completed", from: "assigned" },
        "RenewTraining" => { target: "completed", from: "completed" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def assigned?; @target == "assigned"; end
      def completed?; @target == "completed"; end
    end
  end
end
