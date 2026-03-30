module ComplianceDomain
  class GovernancePolicy
    module Commands
      class UpdateReviewDate
        include Hecks::Command
        emits "UpdatedReviewDate"

        attr_reader :policy_id, :review_date

        def initialize(policy_id: nil, review_date: nil)
          @policy_id = policy_id
          @review_date = review_date
        end

        def call
          existing = repository.find(policy_id)
          if existing
            GovernancePolicy.new(
              id: existing.id,
              name: existing.name,
              description: existing.description,
              category: existing.category,
              framework_id: existing.framework_id,
              effective_date: existing.effective_date,
              review_date: review_date,
              requirements: existing.requirements,
              status: existing.status
            )
          else
            raise ComplianceDomain::Error, "GovernancePolicy not found: #{policy_id}"
          end
        end
      end
    end
  end
end
