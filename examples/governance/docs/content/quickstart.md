```ruby
require "hecks"

# Load and boot all 5 domains with shared event bus
domains = %w[identity model_registry risk_assessment compliance operations].map do |name|
  eval(File.read("domains/#{name}.rb"))
end
shared_bus = Hecks::EventBus.new
apps = domains.map { |d| Hecks::Runtime.new(d, event_bus: shared_bus) }

# Register a stakeholder and vendor
alice = Stakeholder.register(name: "Alice", email: "alice@gov.ai", role: "assessor", team: "risk")
openai = Vendor.register(name: "OpenAI", contact_email: "e@openai.com", risk_tier: "high")

# Register and assess a model
gpt = AiModel.register(name: "GPT-5", version: "1.0", provider_id: openai.id, description: "LLM")
assessment = Assessment.initiate(model_id: gpt.id, assessor_id: alice.id)
Assessment.submit(assessment_id: assessment.id, risk_level: "high",
  bias_score: 0.35, safety_score: 0.72, transparency_score: 0.5, overall_score: 0.52)

# Events flow: SubmittedAssessment → ClassifyRisk (auto)
gpt = AiModel.find(gpt.id)
gpt.risk_level  # => "high"
gpt.classified?  # => true

# Create policy, review, approve
policy = GovernancePolicy.create(name: "EU AI Act", description: "...", category: "regulatory")
review = ComplianceReview.open(model_id: gpt.id, policy_id: policy.id, reviewer_id: alice.id)
ComplianceReview.approve(review_id: review.id, notes: "Passed")
AiModel.approve(model_id: gpt.id)
```
