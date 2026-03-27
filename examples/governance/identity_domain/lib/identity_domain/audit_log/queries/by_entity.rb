module IdentityDomain
  class AuditLog
    module Queries
      class ByEntity
        def call(entity_type, entity_id)
          where(entity_type: entity_type, entity_id: entity_id)
        end
      end
    end
  end
end
