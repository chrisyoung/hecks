module OperationsDomain
  class Incident
    module Commands
      class ResolveIncident
        include Hecks::Command
        emits "ResolvedIncident"

        attr_reader :incident_id
        attr_reader :resolution
        attr_reader :root_cause

        def initialize(
          incident_id: nil,
          resolution: nil,
          root_cause: nil
        )
          @incident_id = incident_id
          @resolution = resolution
          @root_cause = root_cause
        end

        def call
          existing = repository.find(incident_id)
          if existing
            unless ["investigating", "mitigating"].include?(existing.status)
              raise OperationsDomain::Error, "Cannot ResolveIncident: status must be one of investigating, mitigating, got '#{existing.status}'"
            end
            Incident.new(
              id: existing.id,
              model_id: existing.model_id,
              severity: existing.severity,
              category: existing.category,
              description: existing.description,
              reported_by_id: existing.reported_by_id,
              reported_at: existing.reported_at,
              resolution: resolution,
              root_cause: root_cause,
              resolved_at: Time.now.to_s,
              status: "resolved"
            )
          else
            raise OperationsDomain::Error, "Incident not found: #{incident_id}"
          end
        end
      end
    end
  end
end
