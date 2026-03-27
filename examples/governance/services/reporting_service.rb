# ReportingService
#
# Generates compliance reports across all domains. Reads model inventory,
# risk assessments, compliance reviews, incidents, and deployments.
#
#   report = ReportingService.compliance_report
#   report = ReportingService.model_report(model_id: id)
#   report = ReportingService.incident_summary
#
class ReportingService
  ModelReport = Struct.new(:model, :vendor, :risk_assessment, :reviews,
                           :deployments, :incidents, :agreements,
                           :exemptions, :compliant, keyword_init: true)

  def self.compliance_report(framework_id: nil)
    models = AiModel.all
    policies = framework_id ? GovernancePolicy.by_framework(framework_id) : GovernancePolicy.active

    models.map do |model|
      model_report(model_id: model.id, policies: policies)
    end
  end

  def self.model_report(model_id:, policies: nil)
    model = AiModel.find(model_id)
    vendor = model.provider_id ? Vendor.find(model.provider_id) : nil
    assessments = Assessment.by_model(model_id)
    latest = assessments.max_by(&:id)
    reviews = ComplianceReview.by_model(model_id)
    deployments = Deployment.by_model(model_id)
    incidents = Incident.by_model(model_id)
    agreements = DataUsageAgreement.by_model(model_id)
    exemptions = Exemption.by_model(model_id).select { |e| e.status == "active" }

    policies ||= GovernancePolicy.active
    gaps = policies.count do |p|
      next false if exemptions.any? { |e| e.policy_id == p.id }
      review = reviews.find { |r| r.policy_id == p.id }
      review.nil? || review.status != "approved"
    end

    ModelReport.new(
      model: model, vendor: vendor, risk_assessment: latest,
      reviews: reviews, deployments: deployments, incidents: incidents,
      agreements: agreements, exemptions: exemptions,
      compliant: gaps == 0 && model.status != "suspended"
    )
  end

  def self.incident_summary(since: nil)
    incidents = Incident.all
    incidents = incidents.select { |i| i.reported_at.to_s >= since.to_s } if since
    {
      total: incidents.size,
      by_severity: incidents.group_by(&:severity).transform_values(&:size),
      by_status: incidents.group_by(&:status).transform_values(&:size),
      by_category: incidents.group_by(&:category).transform_values(&:size),
      open: incidents.count { |i| i.status != "closed" }
    }
  end

  def self.audit_export(entity_type: nil)
    entries = AuditLog.all
    entries = entries.select { |e| e.entity_type == entity_type } if entity_type
    entries.map do |e|
      { entity_type: e.entity_type, entity_id: e.entity_id,
        action: e.action, actor_id: e.actor_id,
        details: e.details, timestamp: e.timestamp }
    end
  end
end
