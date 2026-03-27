module ModelRegistryDomain
  class AiModel
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "draft" unless defined?(DEFAULT)
      STATES = ["draft", "classified", "approved", "suspended", "retired"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "RegisterModel" => "draft",
        "DeriveModel" => "draft",
        "ClassifyRisk" => { target: "classified", from: "draft" },
        "ApproveModel" => { target: "approved", from: "classified" },
        "SuspendModel" => { target: "suspended", from: ["approved", "classified", "draft"] },
        "RetireModel" => { target: "retired", from: ["approved", "suspended"] },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def draft?; @target == "draft"; end
      def classified?; @target == "classified"; end
      def approved?; @target == "approved"; end
      def suspended?; @target == "suspended"; end
      def retired?; @target == "retired"; end
    end
  end
end
