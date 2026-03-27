```
                    ┌─────────────────────────────────────────────┐
                    │              Model Registry                  │
Register ──► draft ──► ClassifyRisk ──► classified ──► approved    │
                                            │            │         │
                                            └──► suspended ◄──┘   │
                                                     │             │
                                                     └──► retired  │
                    └─────────────────────────────────────────────┘
                         ▲                    ▲            ▲
                         │                    │            │
              SubmittedAssessment    RejectedReview   ReportedIncident
                         │                    │         (critical)
                    ┌────┘               ┌────┘            │
                    │                    │                  │
              Risk Assessment      Compliance          Operations
```

**5 bounded contexts** communicate via domain events:

1. **Identity** — Stakeholder, AuditLog (shared kernel, listens to all)
2. **Model Registry** — AiModel, Vendor, DataUsageAgreement (reacts to assessment/compliance/incident events)
3. **Risk Assessment** — Assessment (publishes SubmittedAssessment)
4. **Compliance** — GovernancePolicy, RegulatoryFramework, ComplianceReview, Exemption, TrainingRecord (publishes RejectedReview)
5. **Operations** — Deployment, Incident, Monitoring (publishes ReportedIncident)
