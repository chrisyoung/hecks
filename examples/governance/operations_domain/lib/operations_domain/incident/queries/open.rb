module OperationsDomain
  class Incident
    module Queries
      class Open
        def call
          where(status: "reported")
        end
      end
    end
  end
end
