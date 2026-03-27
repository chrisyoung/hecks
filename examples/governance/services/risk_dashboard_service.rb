# RiskDashboardService
#
# Aggregates dashboard data across all 5 domains.
#
#   dashboard = RiskDashboardService.summary
#
class RiskDashboardService
  Summary = Struct.new(
    :models_by_risk, :models_by_status,
    :pending_assessments, :open_reviews,
    :open_incidents, :active_deployments,
    :expiring_agreements, :overdue_training,
    keyword_init: true
  )

  def self.summary(expiring_within_days: 30)
    models = AiModel.all
    cutoff = (Date.today + expiring_within_days).strftime("%Y-%m-%d")

    Summary.new(
      models_by_risk: models.group_by(&:risk_level).transform_values(&:size),
      models_by_status: models.group_by(&:status).transform_values(&:size),
      pending_assessments: Assessment.pending,
      open_reviews: ComplianceReview.pending,
      open_incidents: Incident.open,
      active_deployments: Deployment.active,
      expiring_agreements: DataUsageAgreement.active.select { |a| a.expiration_date && a.expiration_date.to_s <= cutoff },
      overdue_training: TrainingRecord.incomplete
    )
  end
end
