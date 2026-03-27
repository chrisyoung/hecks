module ComplianceDomain
  class TrainingRecord
    module Events
      class CompletedTraining
        attr_reader :aggregate_id, :training_record_id, :certification_id, :expires_at, :stakeholder_id, :policy_id, :completed_at, :status, :occurred_at

        def initialize(aggregate_id: nil, training_record_id: nil, certification_id: nil, expires_at: nil, stakeholder_id: nil, policy_id: nil, completed_at: nil, status: nil)
          @aggregate_id = aggregate_id
          @training_record_id = training_record_id
          @certification_id = certification_id
          @expires_at = expires_at
          @stakeholder_id = stakeholder_id
          @policy_id = policy_id
          @completed_at = completed_at
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
