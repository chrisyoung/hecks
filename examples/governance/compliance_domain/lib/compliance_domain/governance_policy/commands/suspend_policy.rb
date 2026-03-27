module ComplianceDomain
  class GovernancePolicy
    module Commands
      class SuspendPolicy
        include Hecks::Command
        emits "SuspendedPolicy"

        attr_reader :policy_id

        def initialize(policy_id: nil)
          @policy_id = policy_id
        end

        def call
          existing = repository.find(policy_id)
          if existing
            unless existing.status == "active"
              raise Hecks::Error, "Cannot SuspendPolicy: status must be 'active', got '#{existing.status}'"
            end
            GovernancePolicy.new(
              id: existing.id,
              name: existing.name,
              description: existing.description,
              category: existing.category,
              framework_id: existing.framework_id,
              effective_date: existing.effective_date,
              review_date: existing.review_date,
              requirements: existing.requirements,
              status: "suspended"
            )
          else
            raise Hecks::Error, "GovernancePolicy not found: #{policy_id}"
          end
        end
      end
    end
  end
end
