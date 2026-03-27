module OperationsDomain
  class Incident
    module Commands
      class ReportIncident
        include Hecks::Command
        emits "ReportedIncident"

        attr_reader :model_id
        attr_reader :severity
        attr_reader :category
        attr_reader :description
        attr_reader :reported_by_id

        def initialize(
          model_id: nil,
          severity: nil,
          category: nil,
          description: nil,
          reported_by_id: nil
        )
          @model_id = model_id
          @severity = severity
          @category = category
          @description = description
          @reported_by_id = reported_by_id
        end

        def call
          Incident.new(
            model_id: model_id,
            severity: severity,
            category: category,
            description: description,
            reported_by_id: reported_by_id,
            reported_at: Time.now.to_s,
            status: "reported"
          )
        end
      end
    end
  end
end
