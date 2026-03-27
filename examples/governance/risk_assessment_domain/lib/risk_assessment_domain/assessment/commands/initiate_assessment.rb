module RiskAssessmentDomain
  class Assessment
    module Commands
      class InitiateAssessment
        include Hecks::Command
        emits "InitiatedAssessment"

        attr_reader :model_id, :assessor_id

        def initialize(model_id: nil, assessor_id: nil)
          @model_id = model_id
          @assessor_id = assessor_id
        end

        def call
          Assessment.new(
            model_id: model_id,
            assessor_id: assessor_id,
            status: "pending"
          )
        end
      end
    end
  end
end
