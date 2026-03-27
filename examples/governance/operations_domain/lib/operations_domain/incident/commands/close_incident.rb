module OperationsDomain
  class Incident
    module Commands
      class CloseIncident
        include Hecks::Command
        emits "ClosedIncident"

        attr_reader :incident_id

        def initialize(incident_id: nil)
          @incident_id = incident_id
        end

        def call
          existing = repository.find(incident_id)
          if existing
            unless existing.status == "resolved"
              raise Hecks::Error, "Cannot CloseIncident: status must be 'resolved', got '#{existing.status}'"
            end
            Incident.new(
              id: existing.id,
              model_id: existing.model_id,
              severity: existing.severity,
              category: existing.category,
              description: existing.description,
              reported_by_id: existing.reported_by_id,
              reported_at: existing.reported_at,
              resolved_at: existing.resolved_at,
              resolution: existing.resolution,
              root_cause: existing.root_cause,
              status: "closed"
            )
          else
            raise Hecks::Error, "Incident not found: #{incident_id}"
          end
        end
      end
    end
  end
end
