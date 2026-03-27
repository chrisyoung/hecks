module IdentityDomain
  class AuditLog
    module Commands
      class RecordEntry
        include Hecks::Command
        emits "RecordedEntry"

        attr_reader :entity_type
        attr_reader :entity_id
        attr_reader :action
        attr_reader :actor_id
        attr_reader :details

        def initialize(
          entity_type: nil,
          entity_id: nil,
          action: nil,
          actor_id: nil,
          details: nil
        )
          @entity_type = entity_type
          @entity_id = entity_id
          @action = action
          @actor_id = actor_id
          @details = details
        end

        def call
          AuditLog.new(
            entity_type: entity_type,
            entity_id: entity_id,
            action: action,
            actor_id: actor_id,
            details: details,
            timestamp: Time.now.to_s
          )
        end
      end
    end
  end
end
