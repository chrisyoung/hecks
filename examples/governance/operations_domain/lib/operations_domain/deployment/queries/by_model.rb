module OperationsDomain
  class Deployment
    module Queries
      class ByModel
        def call(model_id)
          where(model_id: model_id)
        end
      end
    end
  end
end
