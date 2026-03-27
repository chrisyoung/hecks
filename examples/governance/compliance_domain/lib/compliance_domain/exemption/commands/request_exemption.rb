module ComplianceDomain
  class Exemption
    module Commands
      class RequestExemption
        include Hecks::Command
        emits "RequestedExemption"

        attr_reader :model_id
        attr_reader :policy_id
        attr_reader :requirement
        attr_reader :reason

        def initialize(
          model_id: nil,
          policy_id: nil,
          requirement: nil,
          reason: nil
        )
          @model_id = model_id
          @policy_id = policy_id
          @requirement = requirement
          @reason = reason
        end

        def call
          Exemption.new(
            model_id: model_id,
            policy_id: policy_id,
            requirement: requirement,
            reason: reason,
            status: "requested"
          )
        end
      end
    end
  end
end
