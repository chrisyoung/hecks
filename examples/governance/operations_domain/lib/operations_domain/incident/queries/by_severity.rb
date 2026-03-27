module OperationsDomain
  class Incident
    module Queries
      class BySeverity
        def call(severity)
          where(severity: severity)
        end
      end
    end
  end
end
