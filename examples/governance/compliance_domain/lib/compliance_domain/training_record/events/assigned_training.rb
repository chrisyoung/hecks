module ComplianceDomain
  class TrainingRecord
    module Events
      class AssignedTraining
        attr_reader :aggregate_id, :stakeholder_id, :policy_id, :completed_at, :expires_at, :certification_id, :status, :occurred_at

        def initialize(aggregate_id: nil, stakeholder_id: nil, policy_id: nil, completed_at: nil, expires_at: nil, certification_id: nil, status: nil)
          @aggregate_id = aggregate_id
          @stakeholder_id = stakeholder_id
          @policy_id = policy_id
          @completed_at = completed_at
          @expires_at = expires_at
          @certification_id = certification_id
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
