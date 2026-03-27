# IncidentResponseService
#
# Orchestrates the incident lifecycle: investigate, mitigate, resolve.
#
#   IncidentResponseService.investigate(incident_id: id)
#   IncidentResponseService.resolve(incident_id: id, resolution: "...", root_cause: "...")
#
class IncidentResponseService
  def self.investigate(incident_id:)
    Incident.investigate(incident_id: incident_id)
  end

  def self.mitigate(incident_id:)
    Incident.mitigate(incident_id: incident_id)
  end

  def self.resolve(incident_id:, resolution:, root_cause:)
    Incident.resolve(incident_id: incident_id, resolution: resolution, root_cause: root_cause)
  end

  def self.close(incident_id:)
    Incident.close(incident_id: incident_id)
  end

  def self.full_resolution(incident_id:, resolution:, root_cause:)
    investigate(incident_id: incident_id)
    mitigate(incident_id: incident_id)
    resolve(incident_id: incident_id, resolution: resolution, root_cause: root_cause)
    close(incident_id: incident_id)
    Incident.find(incident_id)
  end
end
