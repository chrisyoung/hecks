### Identity (shared kernel)

| Aggregate | Purpose |
|---|---|
| **Stakeholder** | People in the system — assessors, reviewers, board members. PII-protected name and email. |
| **AuditLog** | Immutable record of governance actions. Auto-populated by cross-domain policies. |

### Model Registry

| Aggregate | Purpose |
|---|---|
| **AiModel** | Core entity. Versioned, with lifecycle: draft → classified → approved → suspended → retired. |
| **Vendor** | Third-party model providers with risk tiers and review schedules. |
| **DataUsageAgreement** | Tracks data source consent, purpose, and expiration. |

Reacts to events from other domains:
- `SubmittedAssessment` → auto-classifies model risk
- `RejectedReview` → auto-suspends model
- `ReportedIncident` (critical) → auto-suspends model

### Risk Assessment

| Aggregate | Purpose |
|---|---|
| **Assessment** | Risk scoring with bias, safety, transparency, and overall scores (0.0–1.0). |

Publishes `SubmittedAssessment` which triggers risk classification in Model Registry.

### Compliance

| Aggregate | Purpose |
|---|---|
| **GovernancePolicy** | Rules with requirements, mapped to regulatory frameworks. |
| **RegulatoryFramework** | EU AI Act, NIST AI RMF, ISO 42001 — jurisdiction and authority. |
| **ComplianceReview** | Model-vs-policy review with attachments. Approve, reject, or request changes. |
| **Exemption** | Temporary waivers from policy requirements with expiration. |
| **TrainingRecord** | Tracks who completed training on which policy. |

Publishes `RejectedReview` which triggers model suspension in Model Registry.

### Operations

| Aggregate | Purpose |
|---|---|
| **Deployment** | Where approved models run — environment, audience, endpoint. |
| **Incident** | Bias, safety, privacy, and performance incidents with full lifecycle. |
| **Monitoring** | Post-deployment metrics with threshold breach detection. |

Publishes `ReportedIncident` which triggers model suspension (if critical) in Model Registry.
