# RiskAssessment Domain Glossary

## Assessment

An Assessment has a model_id (String).
An Assessment has an assessor_id (String).
An Assessment has a risk_level (String).
An Assessment has a bias_score (Float).
An Assessment has a safety_score (Float).
An Assessment has a transparency_score (Float).
An Assessment has an overall_score (Float).
An Assessment has a submitted_at (DateTime).
An Assessment has many Findings.
An Assessment has many Mitigations.
An Assessment has a status (String).
A Finding is an entity within an Assessment, with its own identity.
  A Finding has a category (String).
  A Finding has a severity (String).
  A Finding has a description (String).
  A Finding has a status (String).
  severity must be valid. (invariant)
A Mitigation is an entity within an Assessment, with its own identity.
  A Mitigation has a finding_category (String).
  A Mitigation has an action (String).
  A Mitigation has a status (String).
You can initiate an Assessment with model id and assessor id. When this happens, an Assessment is initiated. (command)
You can record an Assessment with assessment id, category, severity, and description. When this happens, a Finding is recorded. (command)
You can submit an Assessment with assessment id, risk level, bias score, safety score, transparency score, and overall score. When this happens, an Assessment is submitted. (command)
You can reject an Assessment with assessment id. When this happens, an Assessment is rejected. (command)
You can look up Assessments by by_model. (query)
You can look up Assessments by pending. (query)
An Assessment must have a model_id. (validation)
An Assessment must have an assessor_id. (validation)
scores must be between 0 and 1. (invariant)

