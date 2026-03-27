module ComplianceDomain
  class ComplianceReview
    module Events
      class ApprovedReview
        attr_reader :aggregate_id, :review_id, :notes, :model_id, :policy_id, :reviewer_id, :outcome, :completed_at, :conditions, :status, :occurred_at

        def initialize(aggregate_id: nil, review_id: nil, notes: nil, model_id: nil, policy_id: nil, reviewer_id: nil, outcome: nil, completed_at: nil, conditions: nil, status: nil)
          @aggregate_id = aggregate_id
          @review_id = review_id
          @notes = notes
          @model_id = model_id
          @policy_id = policy_id
          @reviewer_id = reviewer_id
          @outcome = outcome
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
