module ComplianceDomain
  class ComplianceReview
    module Events
      class OpenedReview
        attr_reader :aggregate_id, :model_id, :policy_id, :reviewer_id, :outcome, :notes, :completed_at, :conditions, :status, :occurred_at

        def initialize(aggregate_id: nil, model_id: nil, policy_id: nil, reviewer_id: nil, outcome: nil, notes: nil, completed_at: nil, conditions: nil, status: nil)
          @aggregate_id = aggregate_id
          @model_id = model_id
          @policy_id = policy_id
          @reviewer_id = reviewer_id
          @outcome = outcome
          @notes = notes
          @completed_at = completed_at
          @conditions = conditions
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
