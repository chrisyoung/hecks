module IdentityDomain
  class AuditLog
    module Policies
      class AuditModelRegistration
        EVENT   = "RegisteredModel"
        TRIGGER = "RecordEntry"
        ASYNC   = false
        MAP     = {:name=>:details}.freeze
        DEFAULTS = {:entity_type=>"AiModel", :action=>"registered", :actor_id=>"system"}.freeze

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
