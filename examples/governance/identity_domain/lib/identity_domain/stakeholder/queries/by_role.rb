module IdentityDomain
  class Stakeholder
    module Queries
      class ByRole
        def call(role)
          where(role: role)
        end
      end
    end
  end
end
