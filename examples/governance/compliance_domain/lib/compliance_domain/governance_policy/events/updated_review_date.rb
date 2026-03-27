module ComplianceDomain
  class GovernancePolicy
    module Events
      class UpdatedReviewDate
        attr_reader :aggregate_id, :policy_id, :review_date, :name, :description, :category, :framework_id, :effective_date, :requirements, :status, :occurred_at

        def initialize(aggregate_id: nil, policy_id: nil, review_date: nil, name: nil, description: nil, category: nil, framework_id: nil, effective_date: nil, requirements: nil, status: nil)
          @aggregate_id = aggregate_id
          @policy_id = policy_id
          @review_date = review_date
          @name = name
          @description = description
          @category = category
          @framework_id = framework_id
          @effective_date = effective_date
          @requirements = requirements
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
