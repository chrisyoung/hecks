# HecksRuntime

The execution layer — wires domains to adapters and runs commands.

Creates Runtime instances that bind repositories, command buses, event buses, policies, and subscribers. Includes all ports (the interfaces between domain and infrastructure) and the mixins included in generated classes.

## Sub-areas

- **runtime/** — Boot, Configuration, PortSetup, RepositorySetup, PolicySetup, SubscriberSetup, ConnectionSetup, LoadExtensions
- **ports/** — Commands (bus, runner, methods), Queries (builder, operators, scopes), Repository (collection proxy, event recorder), EventBus, Queue
- **mixins/** — Command (full lifecycle), Model (attributes, identity, timestamps), Query (chainable DSL), Specification (composable predicates)
- **extensions/** — Auth, Audit, Logging, RateLimit, Idempotency, Retry, Tenancy, PII
