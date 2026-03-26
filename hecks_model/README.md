# HecksModel

The domain modeling layer — defines the vocabulary for describing business domains.

Contains the intermediate representation (IR) types, the DSL builders that construct them, and the validation rules that check them against DDD constraints.

## Sub-areas

- **domain_model/structure/** — Aggregate, Entity, ValueObject, Attribute, Lifecycle, Invariant, Validation, Scope, PortDefinition
- **domain_model/behavior/** — Command, Policy, DomainEvent, Query, Specification, Service, Workflow, EventSubscriber
- **dsl/** — AggregateBuilder, CommandBuilder, DomainBuilder, PolicyBuilder, LifecycleBuilder, etc.
- **validation_rules/** — CommandNaming, UniqueAggregateNames, NoBidirectionalReferences, ValidPolicyTriggers, etc.
