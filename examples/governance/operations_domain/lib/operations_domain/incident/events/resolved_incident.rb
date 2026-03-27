module OperationsDomain
  class Incident
    module Events
      class ResolvedIncident
        attr_reader :aggregate_id, :incident_id, :resolution, :root_cause, :model_id, :severity, :category, :description, :reported_by_id, :reported_at, :resolved_at, :status, :occurred_at

        def initialize(aggregate_id: nil, incident_id: nil, resolution: nil, root_cause: nil, model_id: nil, severity: nil, category: nil, description: nil, reported_by_id: nil, reported_at: nil, resolved_at: nil, status: nil)
          @aggregate_id = aggregate_id
          @incident_id = incident_id
          @resolution = resolution
          @root_cause = root_cause
          @model_id = model_id
          @severity = severity
          @category = category
          @description = description
          @reported_by_id = reported_by_id
          @reported_at = reported_at
          @resolved_at = resolved_at
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
