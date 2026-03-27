module OperationsDomain
  class Deployment
    module Commands
      class DecommissionDeployment
        include Hecks::Command
        emits "DecommissionedDeployment"

        attr_reader :deployment_id

        def initialize(deployment_id: nil)
          @deployment_id = deployment_id
        end

        def call
          existing = repository.find(deployment_id)
          if existing
            unless existing.status == "deployed"
              raise Hecks::Error, "Cannot DecommissionDeployment: status must be 'deployed', got '#{existing.status}'"
            end
            Deployment.new(
              id: existing.id,
              model_id: existing.model_id,
              environment: existing.environment,
              endpoint: existing.endpoint,
              purpose: existing.purpose,
              audience: existing.audience,
              deployed_at: existing.deployed_at,
              decommissioned_at: Time.now.to_s,
              status: "decommissioned"
            )
          else
            raise Hecks::Error, "Deployment not found: #{deployment_id}"
          end
        end
      end
    end
  end
end
