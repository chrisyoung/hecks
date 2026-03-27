module OperationsDomain
  class Deployment
    class Lifecycle
      FIELD = :status unless defined?(FIELD)
      DEFAULT = "planned" unless defined?(DEFAULT)
      STATES = ["planned", "deployed", "decommissioned"].freeze unless defined?(STATES)

      TRANSITIONS = {
        "PlanDeployment" => "planned",
        "DeployModel" => { target: "deployed", from: "planned" },
        "DecommissionDeployment" => { target: "decommissioned", from: "deployed" },
      }.freeze unless defined?(TRANSITIONS)

      attr_reader :target

      def call(current_state, command_name)
        entry = TRANSITIONS[command_name]
        @target = entry.is_a?(Hash) ? entry[:target] : entry
        @target ||= current_state
        self
      end

      def planned?; @target == "planned"; end
      def deployed?; @target == "deployed"; end
      def decommissioned?; @target == "decommissioned"; end
    end
  end
end
