module IdentityDomain
  class AuditLog
    module Queries
      class ByActor
        def call(actor_id)
          where(actor_id: actor_id)
        end
      end
    end
  end
end
