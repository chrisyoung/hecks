module OperationsDomain
  class Monitoring
    module Queries
      class ByDeployment
        def call(deployment_id)
          where(deployment_id: deployment_id)
        end
      end
    end
  end
end
