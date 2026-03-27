module ComplianceDomain
  class GovernancePolicy
    module Commands
      class RetirePolicy
        include Hecks::Command
        emits "RetiredPolicy"

        attr_reader :policy_id

        def initialize(policy_id: nil)
          @policy_id = policy_id
        end

        def call
          existing = repository.find(policy_id)
          if existing
            unless ["active", "suspended"].include?(existing.status)
              raise Hecks::Error, "Cannot RetirePolicy: status must be one of active, suspended, got '#{existing.status}'"
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
              status: "retired"
            )
          else
            raise Hecks::Error, "GovernancePolicy not found: #{policy_id}"
          end
        end
      end
    end
  end
end
