### ModelOnboardingService

Orchestrates model registration: creates the model, initiates a risk assessment, creates data usage agreements, and opens compliance reviews against all active policies.

```ruby
result = ModelOnboardingService.onboard(
  name: "GPT-5", version: "1.0", provider_id: vendor.id,
  description: "Large language model", assessor_id: alice.id,
  data_sources: [{ source: "CommonCrawl", purpose: "Pre-training", consent: "public_domain" }]
)
result.model       # => AiModel
result.assessment   # => Assessment
result.agreements   # => [DataUsageAgreement]
result.reviews      # => [ComplianceReview]
```

### ComplianceCheckService

Read-only compliance report. Checks a model against all active policies, considers exemptions, verifies reviewer training, flags open incidents.

```ruby
report = ComplianceCheckService.check(model_id: gpt.id)
report.compliant?         # => false
report.gaps               # => [{ policy: ..., status: "rejected" }, ...]
report.incidents          # => [Incident]
report.exemptions         # => [Exemption]
```

### RiskDashboardService

Cross-domain dashboard aggregation.

```ruby
dashboard = RiskDashboardService.summary
dashboard.models_by_risk       # => { "high" => 1, "low" => 1 }
dashboard.open_incidents       # => [Incident]
dashboard.active_deployments   # => [Deployment]
dashboard.expiring_agreements  # => [DataUsageAgreement]
```

### PeriodicReviewService

Scheduled checks for expired agreements, overdue policy reviews, stale assessments, expiring exemptions, and vendor reviews. Supports auto-revocation.

```ruby
actions = PeriodicReviewService.run(auto_revoke: true)
actions.expired_agreements    # found and revoked
actions.vendor_reviews_due    # vendors needing reassessment
```

### IncidentResponseService

Orchestrates the full incident lifecycle.

```ruby
resolved = IncidentResponseService.full_resolution(
  incident_id: incident.id,
  resolution: "Retrained model with balanced dataset",
  root_cause: "Training data gender imbalance"
)
resolved.status  # => "closed"
```

### NotificationService

Event-driven routing with urgency levels and recipient mapping.

### FullApprovalService

Approves both the compliance review and the model in one call.
