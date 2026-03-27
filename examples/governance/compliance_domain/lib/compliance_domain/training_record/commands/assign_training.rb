module ComplianceDomain
  class TrainingRecord
    module Commands
      class AssignTraining
        include Hecks::Command
        emits "AssignedTraining"

        attr_reader :stakeholder_id, :policy_id

        def initialize(stakeholder_id: nil, policy_id: nil)
          @stakeholder_id = stakeholder_id
          @policy_id = policy_id
        end

        def call
          TrainingRecord.new(
            stakeholder_id: stakeholder_id,
            policy_id: policy_id,
            status: "assigned"
          )
        end
      end
    end
  end
end
