module IdentityDomain
  class Stakeholder
    module Queries
      class ByTeam
        def call(team)
          where(team: team)
        end
      end
    end
  end
end
