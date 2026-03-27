# PeriodicReviewService
#
# Scheduled service checking for overdue governance actions.
# Auto-revokes expired agreements and exemptions.
#
#   actions = PeriodicReviewService.run
#
class PeriodicReviewService
  Actions = Struct.new(:expired_agreements, :revoked_agreements,
                       :overdue_policies, :stale_assessments,
                       :expired_exemptions, :revoked_exemptions,
                       :expired_training, :vendor_reviews_due,
                       keyword_init: true)

  def self.run(max_assessment_age_days: 365, auto_revoke: false)
    expired_agreements = check_expired_agreements
    revoked = auto_revoke ? expired_agreements.map { |a| DataUsageAgreement.revoke(agreement_id: a.id) } : []

    expired_exemptions = check_expiring_exemptions
    revoked_ex = auto_revoke ? expired_exemptions.map { |e| Exemption.revoke(exemption_id: e.id) } : []

    Actions.new(
      expired_agreements: expired_agreements,
      revoked_agreements: revoked,
      overdue_policies: check_overdue_policy_reviews,
      stale_assessments: check_stale_assessments,
      expired_exemptions: expired_exemptions,
      revoked_exemptions: revoked_ex,
      expired_training: check_expired_training,
      vendor_reviews_due: check_vendor_reviews
    )
  end

  def self.check_expired_agreements
    today = Date.today.strftime("%Y-%m-%d")
    DataUsageAgreement.active.select { |a| a.expiration_date && a.expiration_date.to_s < today }
  end

  def self.check_overdue_policy_reviews
    today = Date.today.strftime("%Y-%m-%d")
    GovernancePolicy.active.select { |p| p.review_date && p.review_date.to_s < today }
  end

  def self.check_stale_assessments
    AiModel.all.select { |model| Assessment.by_model(model.id).empty? }
  end

  def self.check_expiring_exemptions
    today = Date.today.strftime("%Y-%m-%d")
    Exemption.active.select { |e| e.expires_at && e.expires_at.to_s < today }
  end

  def self.check_expired_training
    TrainingRecord.incomplete
  end

  def self.check_vendor_reviews
    today = Date.today.strftime("%Y-%m-%d")
    Vendor.active.select { |v| v.next_review_date && v.next_review_date.to_s < today }
  end
end
