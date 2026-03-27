module ComplianceDomain
  class RegulatoryFramework
    module Queries
      class ByJurisdiction
        def call(jurisdiction)
          where(jurisdiction: jurisdiction)
        end
      end
    end
  end
end
