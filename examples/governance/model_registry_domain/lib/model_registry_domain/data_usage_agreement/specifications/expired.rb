module ModelRegistryDomain
  class DataUsageAgreement
    module Specifications
      class Expired
        def satisfied_by?(agreement)
          agreement.expiration_date && agreement.expiration_date.to_s < Date.today.to_s
        end
      end
    end
  end
end
