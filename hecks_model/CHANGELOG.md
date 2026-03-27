# Changelog

## 0.1.0 (Unreleased)

- Initial release as a standalone component

### 2026-03-27

- Implicit DSL: infer aggregates, commands, value objects, attributes from structure
  - PascalCase blocks → aggregates/value objects, snake_case blocks → commands
  - Bare `name Type` → attributes, `list_of`/`ref` work as expected
  - Command name inference from aggregate context
- `ref()` alias for `reference_to()` in AttributeCollector
- `port :name, [methods]` compact inline form in AggregateBuilder
- `method_missing` on DomainBuilder, AggregateBuilder, CommandBuilder, ValueObjectBuilder
