module OperationsDomain
  class Deployment
    module Commands
      class DeployModel
        include Hecks::Command
        emits "DeployedModel"

        attr_reader :deployment_id

        def initialize(deployment_id: nil)
          @deployment_id = deployment_id
        end

        def call
          existing = repository.find(deployment_id)
          if existing
            unless existing.status == "planned"
              raise Hecks::Error, "Cannot DeployModel: status must be 'planned', got '#{existing.status}'"
            end
            Deployment.new(
              id: existing.id,
              model_id: existing.model_id,
              environment: existing.environment,
              endpoint: existing.endpoint,
              purpose: existing.purpose,
              audience: existing.audience,
              decommissioned_at: existing.decommissioned_at,
              deployed_at: Time.now.to_s,
              status: "deployed"
            )
          else
            raise Hecks::Error, "Deployment not found: #{deployment_id}"
          end
        end
      end
    end
  end
end
