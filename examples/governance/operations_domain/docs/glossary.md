# Operations Domain Glossary

## Deployment

A Deployment has a model_id (String).
A Deployment has an environment (String).
A Deployment has an endpoint (String).
A Deployment has a purpose (String).
A Deployment has an audience (String).
A Deployment has a deployed_at (DateTime).
A Deployment has a decommissioned_at (DateTime).
A Deployment has a status (String).
You can plan a Deployment with model id, environment, endpoint, purpose, and audience. When this happens, a Deployment is planned. (command)
You can deploy a Deployment with deployment id. When this happens, a Model is deployed. (command)
You can decommission a Deployment with deployment id. When this happens, a Deployment is decommissioned. (command)
You can look up Deployments by by model. (query)
You can look up Deployments by by environment. (query)
You can look up Deployments by active. (query)
A Deployment must have a model_id. (validation)
A Deployment must have an environment. (validation)

## Incident

An Incident has a model_id (String).
An Incident has a severity (String).
An Incident has a category (String).
An Incident has a description (String).
An Incident has a reported_by_id (String).
An Incident has a reported_at (DateTime).
An Incident has a resolved_at (DateTime).
An Incident has a resolution (String).
An Incident has a root_cause (String).
An Incident has a status (String).
You can report an Incident with model id, severity, category, description, and reported by id. When this happens, an Incident is reported. (command)
You can investigate an Incident with incident id. When this happens, an Incident is investigated. (command)
You can mitigate an Incident with incident id. When this happens, an Incident is mitigated. (command)
You can resolve an Incident with incident id, resolution, and root cause. When this happens, an Incident is resolved. (command)
You can close an Incident with incident id. When this happens, an Incident is closed. (command)
You can look up Incidents by by model. (query)
You can look up Incidents by by severity. (query)
You can look up Incidents by open. (query)
An Incident must have a model_id. (validation)
An Incident must have a severity. (validation)

## Monitoring

A Monitoring has a model_id (String).
A Monitoring has a deployment_id (String).
A Monitoring has a metric_name (String).
A Monitoring has a value (Float).
A Monitoring has a threshold (Float).
A Monitoring has a recorded_at (DateTime).
You can record a Monitoring with model id, deployment id, metric name, value, and threshold. When this happens, a Metric is recorded. (command)
You can set a Monitoring with monitoring id and threshold. When this happens, a Threshold is set. (command)
You can look up Monitorings by by model. (query)
You can look up Monitorings by by deployment. (query)
A Monitoring must have a model_id. (validation)
A Monitoring must have a metric_name. (validation)
threshold must be positive. (invariant)

