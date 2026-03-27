module ModelRegistryDomain
  class Vendor
    module Queries
      class Active
        def call
          where(status: "approved")
        end
      end
    end
  end
end
