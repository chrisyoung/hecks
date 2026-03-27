require "date"

Hecks.domain "Identity" do
  aggregate "Stakeholder" do
    attribute :name, String, pii: true
    attribute :email, String, pii: true
    attribute :role, String, enum: %w[assessor reviewer governance_board data_steward incident_reporter admin auditor]
    attribute :team, String

    attribute :status, String
    lifecycle :status, default: "active" do
      transition "RegisterStakeholder"   => "active"
      transition "DeactivateStakeholder" => "deactivated", from: "active"
    end

    validation :name, presence: true
    validation :email, presence: true

    command "RegisterStakeholder" do
      attribute :name, String
      attribute :email, String
      attribute :role, String
      attribute :team, String
    end

    command "AssignRole" do
      attribute :stakeholder_id, String
      attribute :role, String
      sets role: :role
    end

    command "DeactivateStakeholder" do
      attribute :stakeholder_id, String
      actor "admin"
    end

    query "ByRole" do |role|
      where(role: role)
    end

    query "ByTeam" do |team|
      where(team: team)
    end

    query "Active" do
      where(status: "active")
    end
  end

  aggregate "AuditLog" do
    attribute :entity_type, String
    attribute :entity_id, String
    attribute :action, String
    attribute :actor_id, String
    attribute :details, String
    attribute :timestamp, DateTime

    validation :entity_type, presence: true
    validation :action, presence: true

    command "RecordEntry" do
      attribute :entity_type, String
      attribute :entity_id, String
      attribute :action, String
      attribute :actor_id, String
      attribute :details, String
      sets timestamp: :now
    end

    query "ByEntity" do |entity_type, entity_id|
      where(entity_type: entity_type, entity_id: entity_id)
    end

    query "ByActor" do |actor_id|
      where(actor_id: actor_id)
    end

    # React to events from other domains
    policy "AuditModelRegistration" do
      on "RegisteredModel"
      trigger "RecordEntry"
      map name: :details
      defaults entity_type: "AiModel", action: "registered", actor_id: "system"
    end

    policy "AuditModelSuspension" do
      on "SuspendedModel"
      trigger "RecordEntry"
      defaults entity_type: "AiModel", action: "suspended", actor_id: "system"
    end

    policy "AuditIncidentReport" do
      on "ReportedIncident"
      trigger "RecordEntry"
      map description: :details
      defaults entity_type: "Incident", action: "reported", actor_id: "system"
    end
  end
end
