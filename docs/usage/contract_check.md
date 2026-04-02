# Versioned API Contracts

Track your domain's public API surface over time and detect breaking
changes automatically.

## Save a Baseline

```bash
hecks contract_check --save
# => Saved API contract to api_contract.json
```

This serializes aggregates, attributes, commands, events, queries, and
finders into a stable JSON structure.

## Check for Changes

```bash
hecks contract_check
```

Output:

```
3 contract differences:
  + added_attribute: Pizza.size
  + added_command: Pizza.ResizePizza
  - removed_attribute: Pizza.calories    <- BREAKING
```

## Programmatic Usage

```ruby
require "hecks/domain_versioning/api_contract"

old_contract = JSON.parse(File.read("api_contract.json"), symbolize_names: true)
new_contract = Hecks::DomainVersioning::ApiContract.serialize(domain)
diffs = Hecks::DomainVersioning::ApiContract.diff(old_contract, new_contract)

diffs.each { |d| puts "#{d[:type]}: #{d[:detail]}" }
```

## Breaking Change Detection

The BreakingClassifier now covers additional kinds:

| Breaking | Non-breaking |
|----------|-------------|
| remove_aggregate | add_aggregate |
| remove_attribute | add_attribute |
| remove_command | add_command |
| remove_query | add_query |
| remove_scope | add_scope |
| remove_finder | add_finder |
