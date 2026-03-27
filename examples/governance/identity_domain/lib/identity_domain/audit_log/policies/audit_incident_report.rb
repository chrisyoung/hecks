module IdentityDomain
  class AuditLog
    module Policies
      class AuditIncidentReport
        EVENT   = "ReportedIncident"
        TRIGGER = "RecordEntry"
        ASYNC   = false
        MAP     = {:description=>:details}.freeze
        DEFAULTS = {:entity_type=>"Incident", :action=>"reported", :actor_id=>"system"}.freeze

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
