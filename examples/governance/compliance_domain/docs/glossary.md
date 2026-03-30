# Compliance Domain Glossary

## GovernancePolicy

A GovernancePolicy has a name (String).
A GovernancePolicy has a description (String).
A GovernancePolicy has a category (String).
A GovernancePolicy belongs to a RegulatoryFramework.
A GovernancePolicy has an effective_date (Date).
A GovernancePolicy has a review_date (Date).
A GovernancePolicy has many Requirements.
A GovernancePolicy has a status (String).
A Requirement is part of a GovernancePolicy.
  A Requirement has a description (String).
  A Requirement has a priority (String).
  A Requirement has a category (String).
You can create a GovernancePolicy with name, description, category, and framework id. When this happens, a Policy is created. (command)
You can activate a GovernancePolicy with policy id and effective date. When this happens, a Policy is activated. (command)
You can suspend a GovernancePolicy with policy id. When this happens, a Policy is suspended. (command)
You can retire a GovernancePolicy with policy id. When this happens, a Policy is retired. (command)
You can update a GovernancePolicy with policy id and review date. When this happens, a ReviewDate is updated. (command)
You can look up GovernancePolicies by by_category. (query)
You can look up GovernancePolicies by by_framework. (query)
You can look up GovernancePolicies by active. (query)
A GovernancePolicy must have a name. (validation)
A GovernancePolicy must have a category. (validation)

## RegulatoryFramework

A RegulatoryFramework has a name (String).
A RegulatoryFramework has a jurisdiction (String).
A RegulatoryFramework has a version (String).
A RegulatoryFramework has an effective_date (Date).
A RegulatoryFramework has an authority (String).
A RegulatoryFramework has many FrameworkRequirements.
A RegulatoryFramework has a status (String).
A FrameworkRequirement is part of a RegulatoryFramework.
  A FrameworkRequirement has an article (String).
  A FrameworkRequirement has a section (String).
  A FrameworkRequirement has a description (String).
  A FrameworkRequirement has a risk_category (String).
You can register a RegulatoryFramework with name, jurisdiction, version, and authority. When this happens, a Framework is registered. (command)
You can activate a RegulatoryFramework with framework id and effective date. When this happens, a Framework is activated. (command)
You can retire a RegulatoryFramework with framework id. When this happens, a Framework is retired. (command)
You can look up RegulatoryFrameworks by by_jurisdiction. (query)
You can look up RegulatoryFrameworks by active. (query)
A RegulatoryFramework must have a name. (validation)
A RegulatoryFramework must have a jurisdiction. (validation)

## ComplianceReview

A ComplianceReview has a model_id (String).
A ComplianceReview belongs to a GovernancePolicy.
A ComplianceReview has a reviewer_id (String).
A ComplianceReview has an outcome (String).
A ComplianceReview has a notes (String).
A ComplianceReview has a completed_at (DateTime).
A ComplianceReview has many ReviewConditions.
A ComplianceReview has a status (String).
A ReviewCondition is part of a ComplianceReview.
  A ReviewCondition has a requirement (String).
  A ReviewCondition has a met (String).
  A ReviewCondition has an evidence (String).
You can open a ComplianceReview with model id, policy id, and reviewer id. When this happens, a Review is opened. (command)
You can approve a ComplianceReview with review id and notes. When this happens, a Review is approved. (command)
You can reject a ComplianceReview with review id and notes. When this happens, a Review is rejected. (command)
You can request a ComplianceReview with review id and notes. When this happens, a Changes is requested. (command)
You can look up ComplianceReviews by by_model. (query)
You can look up ComplianceReviews by pending. (query)
You can look up ComplianceReviews by by_reviewer. (query)
A ComplianceReview must have a model_id. (validation)
A ComplianceReview must have a reviewer_id. (validation)

## Exemption

An Exemption has a model_id (String).
An Exemption belongs to a GovernancePolicy.
An Exemption has a requirement (String).
An Exemption has a reason (String).
An Exemption has an approved_by_id (String).
An Exemption has an approved_at (DateTime).
An Exemption has an expires_at (Date).
An Exemption has a scope (String).
An Exemption has a status (String).
You can request an Exemption with model id, policy id, requirement, and reason. When this happens, an Exemption is requested. (command)
You can approve an Exemption with exemption id, approved by id, and expires at. When this happens, an Exemption is approved. (command)
You can revoke an Exemption with exemption id. When this happens, an Exemption is revoked. (command)
You can look up Exemptions by by_model. (query)
You can look up Exemptions by active. (query)
An Exemption must have a model_id. (validation)
An Exemption must have a policy_id. (validation)

## TrainingRecord

A TrainingRecord has a stakeholder_id (String).
A TrainingRecord belongs to a GovernancePolicy.
A TrainingRecord has a completed_at (DateTime).
A TrainingRecord has an expires_at (Date).
A TrainingRecord has a certification (String).
A TrainingRecord has a status (String).
You can assign a TrainingRecord with stakeholder id and policy id. When this happens, a Training is assigned. (command)
You can complete a TrainingRecord with training record id, certification, and expires at. When this happens, a Training is completed. (command)
You can renew a TrainingRecord with training record id, certification, and expires at. When this happens, a Training is renewed. (command)
You can look up TrainingRecords by by_stakeholder. (query)
You can look up TrainingRecords by by_policy. (query)
You can look up TrainingRecords by incomplete. (query)
A TrainingRecord must have a stakeholder_id. (validation)
A TrainingRecord must have a policy_id. (validation)
expires_at must be after completed_at. (invariant)

## Relationships

A GovernancePolicy references a RegulatoryFramework.
A ComplianceReview references a GovernancePolicy.
An Exemption references a GovernancePolicy.
A TrainingRecord references a GovernancePolicy.
