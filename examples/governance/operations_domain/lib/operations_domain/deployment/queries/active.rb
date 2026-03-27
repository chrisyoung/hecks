module OperationsDomain
  class Deployment
    module Queries
      class Active
        def call
          where(status: "deployed")
        end
      end
    end
  end
end
