# Identity Domain Glossary

## Stakeholder

A Stakeholder has a name (String).
A Stakeholder has an email (String).
A Stakeholder has a role (String).
A Stakeholder has a team (String).
A Stakeholder has a status (String).
You can register a Stakeholder with name, email, role, and team. When this happens, a Stakeholder is registered. (command)
You can assign a Stakeholder with stakeholder id and role. When this happens, a Role is assigned. (command)
You can deactivate a Stakeholder with stakeholder id. When this happens, a Stakeholder is deactivated. (command)
You can look up Stakeholders by by role. (query)
You can look up Stakeholders by by team. (query)
You can look up Stakeholders by active. (query)
A Stakeholder must have a name. (validation)
A Stakeholder must have an email. (validation)

## AuditLog

An AuditLog has an entity_type (String).
An AuditLog has an entity_id (String).
An AuditLog has an action (String).
An AuditLog has an actor_id (String).
An AuditLog has a details (String).
An AuditLog has a timestamp (DateTime).
You can record an AuditLog with entity type, entity id, action, actor id, and details. When this happens, an Entry is recorded. (command)
You can look up AuditLogs by by entity. (query)
You can look up AuditLogs by by actor. (query)
An AuditLog must have an entity_type. (validation)
An AuditLog must have an action. (validation)
When a Model is registered, the system will record Entry. (policy)
When a Model is suspended, the system will record Entry. (policy)
When an Incident is reported, the system will record Entry. (policy)

