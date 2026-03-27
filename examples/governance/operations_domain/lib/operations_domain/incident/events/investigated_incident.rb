module OperationsDomain
  class Incident
    module Events
      class InvestigatedIncident
        attr_reader :aggregate_id, :incident_id, :model_id, :severity, :category, :description, :reported_by_id, :reported_at, :resolved_at, :resolution, :root_cause, :status, :occurred_at

        def initialize(aggregate_id: nil, incident_id: nil, model_id: nil, severity: nil, category: nil, description: nil, reported_by_id: nil, reported_at: nil, resolved_at: nil, resolution: nil, root_cause: nil, status: nil)
          @aggregate_id = aggregate_id
          @incident_id = incident_id
          @model_id = model_id
          @severity = severity
          @category = category
          @description = description
          @reported_by_id = reported_by_id
          @reported_at = reported_at
          @resolved_at = resolved_at
          @resolution = resolution
          @root_cause = root_cause
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
