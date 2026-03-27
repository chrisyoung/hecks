module ComplianceDomain
  class ComplianceReview
    module Commands
      class OpenReview
        include Hecks::Command
        emits "OpenedReview"

        attr_reader :model_id
        attr_reader :policy_id
        attr_reader :reviewer_id

        def initialize(
          model_id: nil,
          policy_id: nil,
          reviewer_id: nil
        )
          @model_id = model_id
          @policy_id = policy_id
          @reviewer_id = reviewer_id
        end

        def call
          ComplianceReview.new(
            model_id: model_id,
            policy_id: policy_id,
            reviewer_id: reviewer_id,
            status: "open"
          )
        end
      end
    end
  end
end
