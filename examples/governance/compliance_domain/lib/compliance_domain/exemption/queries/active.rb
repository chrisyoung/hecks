module ComplianceDomain
  class Exemption
    module Queries
      class Active
        def call
          where(status: "active")
        end
      end
    end
  end
end
