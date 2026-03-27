module ModelRegistryDomain
  class AiModel
    module Policies
      class ClassifyAfterAssessment
        EVENT   = "SubmittedAssessment"
        TRIGGER = "ClassifyRisk"
        ASYNC   = false
        MAP     = {:model_id=>:model_id, :risk_level=>:risk_level}.freeze

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
