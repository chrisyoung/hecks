module OperationsDomain
  class Deployment
    module Queries
      class ByEnvironment
        def call(env)
          where(environment: env)
        end
      end
    end
  end
end
