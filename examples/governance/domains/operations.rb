require "date"

Hecks.domain "Operations" do
  aggregate "Deployment" do
    attribute :model_id, String
    attribute :environment, String, enum: %w[development staging production]
    attribute :endpoint, String
    attribute :purpose, String
    attribute :audience, String, enum: %w[internal customer-facing public]
    attribute :deployed_at, DateTime
    attribute :decommissioned_at, DateTime

    attribute :status, String
    lifecycle :status, default: "planned" do
      transition "PlanDeployment"         => "planned"
      transition "DeployModel"            => "deployed",       from: "planned"
      transition "DecommissionDeployment" => "decommissioned", from: "deployed"
    end

    validation :model_id, presence: true
    validation :environment, presence: true

    command "PlanDeployment" do
      attribute :model_id, String
      attribute :environment, String
      attribute :endpoint, String
      attribute :purpose, String
      attribute :audience, String
    end

    command "DeployModel" do
      attribute :deployment_id, String
      sets deployed_at: :now
    end

    command "DecommissionDeployment" do
      attribute :deployment_id, String
      sets decommissioned_at: :now
    end

    specification "CustomerFacing" do |deployment|
      deployment.audience == "customer-facing" || deployment.audience == "public"
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "ByEnvironment" do |env|
      where(environment: env)
    end

    query "Active" do
      where(status: "deployed")
    end
  end

  aggregate "Incident" do
    attribute :model_id, String
    attribute :severity, String, enum: %w[low medium high critical]
    attribute :category, String, enum: %w[bias safety privacy performance other]
    attribute :description, String
    attribute :reported_by_id, String
    attribute :reported_at, DateTime
    attribute :resolved_at, DateTime
    attribute :resolution, String
    attribute :root_cause, String

    attribute :status, String
    lifecycle :status, default: "reported" do
      transition "ReportIncident"      => "reported"
      transition "InvestigateIncident" => "investigating", from: "reported"
      transition "MitigateIncident"    => "mitigating",    from: "investigating"
      transition "ResolveIncident"     => "resolved",      from: ["investigating", "mitigating"]
      transition "CloseIncident"       => "closed",        from: "resolved"
    end

    validation :model_id, presence: true
    validation :severity, presence: true

    command "ReportIncident" do
      attribute :model_id, String
      attribute :severity, String
      attribute :category, String
      attribute :description, String
      attribute :reported_by_id, String
      sets reported_at: :now
    end

    command "InvestigateIncident" do
      attribute :incident_id, String
    end

    command "MitigateIncident" do
      attribute :incident_id, String
    end

    command "ResolveIncident" do
      attribute :incident_id, String
      attribute :resolution, String
      attribute :root_cause, String
      sets resolved_at: :now
    end

    command "CloseIncident" do
      attribute :incident_id, String
    end

    specification "Critical" do |incident|
      incident.severity == "critical" || incident.category == "safety"
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "BySeverity" do |severity|
      where(severity: severity)
    end

    query "Open" do
      where(status: "reported")
    end
  end

  aggregate "Monitoring" do
    attribute :model_id, String
    attribute :deployment_id, String
    attribute :metric_name, String
    attribute :value, Float
    attribute :threshold, Float
    attribute :recorded_at, DateTime

    validation :model_id, presence: true
    validation :metric_name, presence: true

    invariant "threshold must be positive" do
      !threshold || threshold > 0
    end

    command "RecordMetric" do
      attribute :model_id, String
      attribute :deployment_id, String
      attribute :metric_name, String
      attribute :value, Float
      attribute :threshold, Float
      sets recorded_at: :now
    end

    command "SetThreshold" do
      attribute :monitoring_id, String
      attribute :threshold, Float
      sets threshold: :threshold
    end

    specification "ThresholdBreached" do |m|
      m.threshold && m.value && m.value > m.threshold
    end

    query "ByModel" do |model_id|
      where(model_id: model_id)
    end

    query "ByDeployment" do |deployment_id|
      where(deployment_id: deployment_id)
    end
  end
end
