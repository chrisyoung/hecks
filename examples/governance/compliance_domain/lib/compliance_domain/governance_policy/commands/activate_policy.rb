module ComplianceDomain
  class GovernancePolicy
    module Commands
      class ActivatePolicy
        include Hecks::Command
        emits "ActivatedPolicy"

        attr_reader :policy_id, :effective_date

        def initialize(policy_id: nil, effective_date: nil)
          @policy_id = policy_id
          @effective_date = effective_date
        end

        def call
          existing = repository.find(policy_id)
          if existing
            unless existing.status == "draft"
              raise ComplianceDomain::Error, "Cannot ActivatePolicy: status must be 'draft', got '#{existing.status}'"
            end
            GovernancePolicy.new(
              id: existing.id,
              name: existing.name,
              description: existing.description,
              category: existing.category,
              framework_id: existing.framework_id,
              effective_date: effective_date,
              review_date: existing.review_date,
              requirements: existing.requirements,
              status: "active"
            )
          else
            raise ComplianceDomain::Error, "GovernancePolicy not found: #{policy_id}"
          end
        end
      end
    end
  end
end
