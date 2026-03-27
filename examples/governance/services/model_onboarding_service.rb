# ModelOnboardingService
#
# Orchestrates model registration: creates the model, initiates a risk
# assessment, creates data usage agreements, and opens compliance reviews
# against all active governance policies.
#
#   result = ModelOnboardingService.onboard(name: "GPT-5", ...)
#
class ModelOnboardingService
  Result = Struct.new(:model, :assessment, :agreements, :reviews, keyword_init: true)

  def self.onboard(name:, version:, provider_id: nil, description:, assessor_id:, data_sources: [], review_policies: :all_active)
    model = AiModel.register(name: name, version: version, provider_id: provider_id, description: description)
    assessment = Assessment.initiate(model_id: model.id, assessor_id: assessor_id)

    agreements = data_sources.map do |ds|
      DataUsageAgreement.create(model_id: model.id, data_source: ds[:source], purpose: ds[:purpose], consent_type: ds[:consent])
    end

    policies = review_policies == :all_active ? GovernancePolicy.active : Array(review_policies).map { |id| GovernancePolicy.find(id) }.compact

    reviews = policies.map do |policy|
      ComplianceReview.open(model_id: model.id, policy_id: policy.id, reviewer_id: assessor_id)
    end

    Result.new(model: model, assessment: assessment, agreements: agreements, reviews: reviews)
  end
end
