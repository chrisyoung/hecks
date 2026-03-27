module IdentityDomain
  class Stakeholder
    module Queries
      class Active
        def call
          where(status: "active")
        end
      end
    end
  end
end
