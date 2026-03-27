module OperationsDomain
  class Incident
    module Specifications
      class Critical
        def satisfied_by?(incident)
          incident.severity == "critical" || incident.category == "safety"
        end
      end
    end
  end
end
