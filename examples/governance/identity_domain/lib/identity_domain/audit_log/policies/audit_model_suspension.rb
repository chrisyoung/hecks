module IdentityDomain
  class AuditLog
    module Policies
      class AuditModelSuspension
        EVENT   = "SuspendedModel"
        TRIGGER = "RecordEntry"
        ASYNC   = false
        DEFAULTS = {:entity_type=>"AiModel", :action=>"suspended", :actor_id=>"system"}.freeze

        def self.event   = EVENT
        def self.trigger = TRIGGER
        def self.async   = ASYNC

        attr_reader :result

        def call(event)
          # Maps event attrs and dispatches trigger command
          self
        end
      end
    end
  end
end
