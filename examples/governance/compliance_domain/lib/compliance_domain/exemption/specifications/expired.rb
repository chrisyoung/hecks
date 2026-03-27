module ComplianceDomain
  class Exemption
    module Specifications
      class Expired
        def satisfied_by?(e)
          e.expires_at && e.expires_at.to_s < Date.today.to_s
        end
      end
    end
  end
end
