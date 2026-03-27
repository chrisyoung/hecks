module OperationsDomain
  class Deployment
    module Events
      class DeployedModel
        attr_reader :aggregate_id, :deployment_id, :model_id, :environment, :endpoint, :purpose, :audience, :deployed_at, :decommissioned_at, :status, :occurred_at

        def initialize(aggregate_id: nil, deployment_id: nil, model_id: nil, environment: nil, endpoint: nil, purpose: nil, audience: nil, deployed_at: nil, decommissioned_at: nil, status: nil)
          @aggregate_id = aggregate_id
          @deployment_id = deployment_id
          @model_id = model_id
          @environment = environment
          @endpoint = endpoint
          @purpose = purpose
          @audience = audience
          @deployed_at = deployed_at
          @decommissioned_at = decommissioned_at
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
