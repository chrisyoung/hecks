module OperationsDomain
  class Deployment
    module Specifications
      class CustomerFacing
        def satisfied_by?(deployment)
          deployment.audience == "customer-facing" || deployment.audience == "public"
        end
      end
    end
  end
end
