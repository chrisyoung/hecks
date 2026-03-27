# ComplianceCheckService
#
# Checks a model against all active policies. Considers exemptions,
# incidents, and reviewer training status.
#
#   report = ComplianceCheckService.check(model_id: id)
#   report.compliant?  # => true/false
#
class ComplianceCheckService
  Report = Struct.new(:model, :risk_assessment, :policies_checked, :reviews,
                      :agreements, :exemptions, :gaps, :incidents, keyword_init: true) do
    def compliant?
      gaps.empty? && model.status != "suspended"
    end
  end

  def self.check(model_id:)
    model = AiModel.find(model_id)
    assessments = Assessment.by_model(model_id)
    latest = assessments.max_by(&:id)
    reviews = ComplianceReview.by_model(model_id)
    agreements = DataUsageAgreement.by_model(model_id)
    policies = GovernancePolicy.active
    exemptions = Exemption.by_model(model_id).select { |e| e.status == "active" }
    incidents = Incident.by_model(model_id).select { |i| i.status != "closed" }

    gaps = []
    policies.each do |policy|
      next if exemptions.any? { |e| e.policy_id == policy.id }
      review = reviews.find { |r| r.policy_id == policy.id }

      if review.nil?
        gaps << { policy: policy, requirement: "No review exists", status: "missing" }
      elsif review.status == "rejected"
        gaps << { policy: policy, requirement: review.notes, status: "rejected" }
      elsif review.status != "approved"
        gaps << { policy: policy, requirement: "Review incomplete", status: review.status }
      else
        # Check reviewer training
        trained = TrainingRecord.by_policy(policy.id).any? { |t| t.stakeholder_id == review.reviewer_id && t.status == "completed" }
        gaps << { policy: policy, requirement: "Reviewer not trained on policy", status: "training_gap" } unless trained
      end
    end

    gaps << { policy: nil, requirement: "No risk assessment", status: "missing" } if latest.nil?
    gaps << { policy: nil, requirement: "Model is suspended", status: "blocked" } if model.status == "suspended"
    gaps << { policy: nil, requirement: "Open incidents", status: "blocked" } if incidents.any?

    Report.new(model: model, risk_assessment: latest, policies_checked: policies,
               reviews: reviews, agreements: agreements, exemptions: exemptions,
               gaps: gaps, incidents: incidents)
  end
end
