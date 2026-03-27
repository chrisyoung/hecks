module IdentityDomain
  class AuditLog
    module Events
      class RecordedEntry
        attr_reader :aggregate_id, :entity_type, :entity_id, :action, :actor_id, :details, :timestamp, :occurred_at

        def initialize(aggregate_id: nil, entity_type: nil, entity_id: nil, action: nil, actor_id: nil, details: nil, timestamp: nil)
          @aggregate_id = aggregate_id
          @entity_type = entity_type
          @entity_id = entity_id
          @action = action
          @actor_id = actor_id
          @details = details
          @timestamp = timestamp
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
