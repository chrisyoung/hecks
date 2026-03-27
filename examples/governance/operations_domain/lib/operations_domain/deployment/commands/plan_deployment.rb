module OperationsDomain
  class Deployment
    module Commands
      class PlanDeployment
        include Hecks::Command
        emits "PlannedDeployment"

        attr_reader :model_id
        attr_reader :environment
        attr_reader :endpoint
        attr_reader :purpose
        attr_reader :audience

        def initialize(
          model_id: nil,
          environment: nil,
          endpoint: nil,
          purpose: nil,
          audience: nil
        )
          @model_id = model_id
          @environment = environment
          @endpoint = endpoint
          @purpose = purpose
          @audience = audience
        end

        def call
          Deployment.new(
            model_id: model_id,
            environment: environment,
            endpoint: endpoint,
            purpose: purpose,
            audience: audience,
            status: "planned"
          )
        end
      end
    end
  end
end
