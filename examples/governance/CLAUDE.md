# CLAUDE.md

## What this is

An AI governance platform built with [Hecks](../hecks). 5 bounded contexts, 14 aggregates, cross-domain event communication.

## Rules

- **Domain definitions are the source of truth** — edit `domains/*.rb`, then rebuild
- **Don't hand-edit generated files** — everything under `*_domain/` is generated
- **Tests must run under 1 second** — pre-commit hook enforces this
- **No file over 200 lines** — extract by concern (domain definition files are exempt)
- **Stage specifically** — never `git add -A`, always name files
- **Never write workarounds** — fix bugs in hecks directly, respect hecks CLAUDE.md
- **Always file Linear bugs** — hecks bugs go to Hecks Features project with Bug + New labels

## Before every commit

1. Rebuild domains if definitions changed
2. Pre-commit hook runs all specs automatically
3. All 5 domains must pass, under 1 second each

## Bounded contexts

| Domain | Aggregates | Role |
|---|---|---|
| **Identity** | Stakeholder, AuditLog | Shared kernel — who + audit trail |
| **ModelRegistry** | AiModel, Vendor, DataUsageAgreement | Model catalog + data governance |
| **RiskAssessment** | Assessment | Risk scoring + findings |
| **Compliance** | GovernancePolicy, RegulatoryFramework, ComplianceReview, Exemption, TrainingRecord | Rules engine |
| **Operations** | Deployment, Incident, Monitoring | Runtime governance |

## Cross-domain events

- SubmittedAssessment → ClassifyRisk (Risk → Registry)
- RejectedReview → SuspendModel (Compliance → Registry)
- ReportedIncident → SuspendModel (Operations → Registry, if critical)
- RegisteredModel/SuspendedModel/ReportedIncident → RecordEntry (→ Identity audit)

## Application services

- ModelOnboardingService — orchestrate registration flow
- ComplianceCheckService — cross-domain compliance report
- RiskDashboardService — aggregate dashboard queries
- PeriodicReviewService — scheduled checks with auto-revoke
- NotificationService — event-driven routing
- FullApprovalService — review + model approval
- IncidentResponseService — incident lifecycle orchestration

## Rebuild workflow

```bash
# Rebuild all domains
rm -rf *_domain
ruby -I../hecks/lib app.rb

# Run all specs
for d in *_domain; do cd $d && bundle exec rspec && cd ..; done
```
