# Hecks for DDD Practitioners

If you've read Evans, this is how Hecks maps to the blue book patterns.

## Aggregate Roots

`aggregate` in the DSL. Generated as a class with identity equality (`==` compares by UUID), auto-generated identity, and construction-time validation. The aggregate boundary is enforced — cross-aggregate references are by ID only, validated at build time.

```ruby
aggregate "Pizza" do          # Chapter 6: Aggregates
  attribute :name, String
  attribute :toppings, list_of("Topping")
  validation :name, presence: true
  invariant "name can't be blank" do
    !name.empty?
  end
end
```

## Value Objects

`value_object` in the DSL. Generated as frozen, immutable objects with equality by attributes (not identity). Support invariants for business rules.

```ruby
value_object "Topping" do     # Chapter 5: Value Objects
  attribute :name, String
  attribute :amount, Integer
  invariant "amount must be positive" do
    amount > 0
  end
end
```

## Commands

`command` in the DSL. Represents intent — a request to change state. Each command automatically infers a corresponding domain event (`CreatePizza` -> `CreatedPizza`). Commands are dispatched through a CommandBus with middleware support (Chapter 10: Supple Design).

```ruby
command "CreatePizza" do      # Application Service pattern
  attribute :name, String
end
```

## Domain Events

Auto-generated from commands. Frozen, immutable facts with `occurred_at` timestamps. Published through an in-process EventBus. With `event_sourced: true`, persisted to a `domain_events` table for full audit history.

```ruby
# CreatedPizza event auto-generated from CreatePizza command
app.on("CreatedPizza") { |event| puts event.name }
Pizza.history(id)  # => full event stream (when event sourcing enabled)
```

## Policies

`policy` in the DSL. Reactive rules that subscribe to domain events and trigger commands — Evans' "domain event subscribers" pattern. Policies are the approved mechanism for cross-aggregate and cross-context communication.

```ruby
policy "ReserveIngredients" do   # Chapter 14: Model Integrity
  on "PlacedOrder"
  trigger "ReserveStock"
end
```

## Bounded Contexts

`context` in the DSL. Each context generates a separate module namespace. Cross-context references are forbidden (validated at build time) — contexts communicate through events and policies only.

```ruby
Hecks.domain "Pizzas" do
  context "Ordering" do       # Chapter 14: Bounded Contexts
    aggregate "Order" do ... end
  end
  context "Kitchen" do
    aggregate "Recipe" do
      policy "StartPrep" do
        on "PlacedOrder"      # cross-context via events
        trigger "CreateRecipe"
      end
    end
  end
end
```

## Repositories

Not in the DSL — they're infrastructure. Hecks generates memory repositories by default and SQL repositories on demand. The `RepositoryMethods` mixin binds `find`, `save`, `create`, `delete` onto aggregate classes at boot time. The domain never references repositories directly.

The `.bind` pattern implements the Ports and Adapters (Hexagonal) architecture:

```ruby
# Domain layer: pure aggregate class (no persistence knowledge)
# Infrastructure layer: RepositoryMethods.bind(Pizza, repo) at boot
# Application layer: Hecks::Services::Application orchestrates wiring
```

## Query Objects

`query` in the DSL. Named, reusable queries defined as domain concepts. Internally use a `QueryBuilder` that delegates to the adapter — memory adapters filter in Ruby, SQL adapters build Sequel datasets.

```ruby
query "Classics" do           # Repository pattern: named queries
  where(style: "Classic").order(:name)
end
```

## Ports and Adapters

The hexagonal architecture is implemented via the module grouping pattern:

- **Persistence** — `RepositoryMethods`, `CollectionMethods`, `ReferenceMethods`
- **Querying** — `QueryBuilder`, `AdHocQueries`, `ScopeMethods`, `Operators`
- **Commands** — `CommandBus`, `CommandMethods`

Each group has a `.bind` method that injects behavior into aggregate classes at boot time. The domain gem has zero knowledge of these — they're wired by `AggregateWiring` in the application layer.

## Event Sourcing

Opt-in via `event_sourced: true`. Every command records its event to a `domain_events` table alongside the regular SQL state. Provides `Pizza.history(id)` for full event streams. Regular SQL tables serve as the read model — queries stay fast.

## What Hecks Validates (DDD Rules)

12 rules enforced at build time:

| Rule | Evans Pattern |
|------|--------------|
| Aggregates must have commands | Aggregates need behavior |
| Commands must be verbs | Ubiquitous Language |
| Commands must have attributes | Intent requires data |
| No self-references | Aggregate boundary |
| No bidirectional references | Aggregate boundary |
| No cross-context references | Bounded Context integrity |
| References by ID only | Aggregate Root references |
| Value objects can't hold references | Value Object purity |
| No name collisions | Ubiquitous Language clarity |
| Policy events must exist | Model integrity |
| Policy triggers must exist | Model integrity |
| Unique names | Ubiquitous Language |
