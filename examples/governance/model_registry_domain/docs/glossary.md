# ModelRegistry Domain Glossary

## AiModel

An AiModel has a name (String).
An AiModel has a version (String).
An AiModel has a provider_id (String).
An AiModel has a description (String).
An AiModel has a risk_level (String).
An AiModel has a registered_at (DateTime).
An AiModel has a parent_model_id (String).
An AiModel has a derivation_type (String).
An AiModel has many Capabilities.
An AiModel has many IntendedUses.
An AiModel has a status (String).
A Capability is part of an AiModel.
  A Capability has a name (String).
  A Capability has a category (String).
An IntendedUse is part of an AiModel.
  An IntendedUse has a description (String).
  An IntendedUse has a domain (String).
You can register an AiModel with name, version, provider id, and description. When this happens, a Model is registered. (command)
You can derive an AiModel with name, version, parent model id, derivation type, and description. When this happens, a Model is derived. (command)
You can classify an AiModel with model id and risk level. When this happens, a Risk is classified. (command)
You can approve an AiModel with model id. When this happens, a Model is approved. (command)
You can suspend an AiModel with model id. When this happens, a Model is suspended. (command)
You can retire an AiModel with model id. When this happens, a Model is retired. (command)
You can look up AiModels by by provider. (query)
You can look up AiModels by by risk level. (query)
You can look up AiModels by by status. (query)
You can look up AiModels by by parent. (query)
An AiModel must have a name. (validation)
An AiModel must have a version. (validation)
When an Assessment is submitted, the system will classify Risk. (policy)
When a Review is rejected, the system will suspend Model. (policy)
When an Incident is reported, the system will suspend Model. (policy)

## Vendor

A Vendor has a name (String).
A Vendor has a contact_email (String).
A Vendor has a risk_tier (String).
A Vendor has an assessment_date (Date).
A Vendor has a next_review_date (Date).
A Vendor has a sla_terms (String).
A Vendor has a status (String).
You can register a Vendor with name, contact email, and risk tier. When this happens, a Vendor is registered. (command)
You can approve a Vendor with vendor id, assessment date, and next review date. When this happens, a Vendor is approved. (command)
You can suspend a Vendor with vendor id. When this happens, a Vendor is suspended. (command)
You can look up Vendors by by risk tier. (query)
You can look up Vendors by active. (query)
A Vendor must have a name. (validation)

## DataUsageAgreement

A DataUsageAgreement has a model_id (String).
A DataUsageAgreement has a data_source (String).
A DataUsageAgreement has a purpose (String).
A DataUsageAgreement has a consent_type (String).
A DataUsageAgreement has an effective_date (Date).
A DataUsageAgreement has an expiration_date (Date).
A DataUsageAgreement has many Restrictions.
A DataUsageAgreement has a status (String).
A Restriction is part of a DataUsageAgreement.
  A Restriction has a type (String).
  A Restriction has a description (String).
You can create a DataUsageAgreement with model id, data source, purpose, and consent type. When this happens, an Agreement is created. (command)
You can activate a DataUsageAgreement with agreement id, effective date, and expiration date. When this happens, an Agreement is activated. (command)
You can revoke a DataUsageAgreement with agreement id. When this happens, an Agreement is revoked. (command)
You can renew a DataUsageAgreement with agreement id and expiration date. When this happens, an Agreement is renewed. (command)
You can look up DataUsageAgreements by by model. (query)
You can look up DataUsageAgreements by active. (query)
A DataUsageAgreement must have a data_source. (validation)
A DataUsageAgreement must have a purpose. (validation)
expiration must be after effective date. (invariant)

