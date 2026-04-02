# API Contracts

Versioned API contracts let you detect breaking changes in your domain's
public surface before they reach consumers. The contract captures aggregate
names, attribute names and types, command signatures, and query names.

## Save a baseline

Snapshot the current domain API to `.hecks_api_contract.json`:

```bash
hecks contract_check --save
# => API contract saved to .hecks_api_contract.json
```

The generated file is JSON and should be committed to version control.

## Check for breaking changes

Compare the current domain against the saved baseline:

```bash
hecks contract_check
# => API contract: no changes detected.
```

When breaking changes exist, the command exits non-zero:

```bash
hecks contract_check
# 2 API changes detected:
#
#   - attribute: Widget.color  <- BREAKING
#   ~ type: Widget.name (String -> Integer)  <- BREAKING
#
# 2 breaking changes found!
# Run `hecks contract_check --save` to acknowledge.
```

## Breaking change kinds

The following changes are classified as breaking:

| Kind | Example |
|------|---------|
| `remove_aggregate` | Deleting an entire aggregate |
| `remove_attribute` | Removing a field from an aggregate |
| `remove_command` | Removing a command |
| `change_attribute_type` | Changing `:name` from `String` to `Integer` |
| `rename_attribute` | Renaming `:color` to `:colour` |
| `add_required_command_attribute` | Adding a new required field to a command |

Non-breaking changes (added aggregates, added attributes, added commands)
are reported but do not cause a non-zero exit.

## CI integration

Add to your CI pipeline to block deploys with unacknowledged API changes:

```yaml
# .github/workflows/ci.yml
- name: API contract check
  run: bundle exec hecks contract_check
```

## Acknowledging changes

After reviewing breaking changes, update the baseline:

```bash
hecks contract_check --save
git add .hecks_api_contract.json
git commit -m "Acknowledge API contract changes"
```
