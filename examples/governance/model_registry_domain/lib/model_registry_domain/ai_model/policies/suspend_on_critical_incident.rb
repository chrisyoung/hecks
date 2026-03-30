module ModelRegistryDomain
  class AiModel
    module Policies
      class SuspendOnCriticalIncident
        EVENT   = "ReportedIncident"
        TRIGGER = "SuspendModel"
        ASYNC   = true
        MAP     = {:model_id=>:model_id}.freeze

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
