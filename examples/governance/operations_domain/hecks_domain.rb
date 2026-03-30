Hecks.domain "Operations" do
  uses_kernel "Identity"

  anti_corruption_layer "ModelRegistry" do
    translate "AiModel", model_name: :name
  end

  published_event "IncidentReported", version: 1 do
    attribute :incident_id, String
    attribute :model_id, String
    attribute :severity, String
  end

  saga "IncidentResponse" do
    step "ReportIncident", on_success: "InvestigateIncident"
    step "InvestigateIncident", on_success: "MitigateIncident", on_failure: "EscalateIncident"
    step "MitigateIncident", on_success: "ResolveIncident"
    compensation "EscalateIncident"
  end

  service "IncidentResponseService" do
    coordinates "Incident", "Deployment", "Monitoring"
  end

  aggregate "Deployment" do
    reference_to "ModelRegistry::AiModel", as: :model
    attribute :environment, String
    attribute :endpoint, String
    attribute :purpose, String
    attribute :audience, String
    attribute :deployed_at, DateTime
    attribute :decommissioned_at, DateTime
    attribute :status, String

    validation :model_id, {:presence=>true}

    validation :environment, {:presence=>true}

    query "ByModel" do
      where(model_id: model_id)
    end

    query "ByEnvironment" do
      where(environment: env)
    end

    query "Active" do
      where(status: "deployed")
    end

    specification "CustomerFacing" do |deployment|
      deployment.audience == "customer-facing" || deployment.audience == "public"
    end

    command "PlanDeployment" do
      attribute :model_id, reference_to("AiModel")
      attribute :environment, String
      attribute :endpoint, String
      attribute :purpose, String
      attribute :audience, String
    end

    command "DeployModel" do
      attribute :deployment_id, reference_to("Deployment")
    end

    command "DecommissionDeployment" do
      attribute :deployment_id, reference_to("Deployment")
    end
  end

  aggregate "Incident" do
    reference_to "ModelRegistry::AiModel", as: :model
    attribute :severity, String
    attribute :category, String
    attribute :description, String
    reference_to "Identity::Stakeholder", as: :reported_by
    attribute :reported_at, DateTime
    attribute :resolved_at, DateTime
    attribute :resolution, String
    attribute :root_cause, String
    attribute :status, String

    validation :model_id, {:presence=>true}

    validation :severity, {:presence=>true}

    query "ByModel" do
      where(model_id: model_id)
    end

    query "BySeverity" do
      where(severity: severity)
    end

    query "Open" do
      where(status: "reported")
    end

    specification "Critical" do |incident|
      incident.severity == "critical" || incident.category == "safety"
    end

    command "ReportIncident" do
      attribute :model_id, reference_to("AiModel")
      attribute :severity, String
      attribute :category, String
      attribute :description, String
      attribute :reported_by_id, reference_to("Stakeholder")
    end

    command "InvestigateIncident" do
      attribute :incident_id, reference_to("Incident")
    end

    command "MitigateIncident" do
      attribute :incident_id, reference_to("Incident")
    end

    command "ResolveIncident" do
      attribute :incident_id, reference_to("Incident")
      attribute :resolution, String
      attribute :root_cause, String
    end

    command "CloseIncident" do
      attribute :incident_id, reference_to("Incident")
    end
  end

  aggregate "Monitoring" do
    reference_to "ModelRegistry::AiModel", as: :model
    reference_to "Deployment"
    attribute :metric_name, String
    attribute :value, Float
    attribute :threshold, Float
    attribute :recorded_at, DateTime

    validation :model_id, {:presence=>true}

    validation :metric_name, {:presence=>true}

    invariant "threshold must be positive" do
      !threshold || threshold > 0
    end

    query "ByModel" do
      where(model_id: model_id)
    end

    query "ByDeployment" do
      where(deployment_id: deployment_id)
    end

    specification "ThresholdBreached" do |m|
      m.threshold && m.value && m.value > m.threshold
    end

    command "RecordMetric" do
      attribute :model_id, reference_to("AiModel")
      attribute :deployment_id, reference_to("Deployment")
      attribute :metric_name, String
      attribute :value, Float
      attribute :threshold, Float
    end

    command "SetThreshold" do
      attribute :monitoring_id, reference_to("Monitoring")
      attribute :threshold, Float
    end
  end
end
