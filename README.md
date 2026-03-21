# Hecks

A Hexagonal / Domain-Driven Design framework for Ruby. Define domains with a Ruby DSL, generate pure versioned domain gems.

Hecks separates domain modeling from application concerns. You define your domain once, and Hecks generates a standalone Ruby gem with zero dependencies — just pure domain objects. Changes to the domain require a rebuild, producing a new versioned artifact that applications consume.

## Hecks LOVES Rails

Drop a Hecks domain gem into any Rails app and it just works. No ActiveRecord needed.

```ruby
# Gemfile
gem "hecks"
gem "pizzas_domain", path: "./pizzas_domain"

# config/initializers/hecks.rb
Hecks.configure do
  domain "pizzas_domain"
  adapter :sql unless Rails.env.test?
end
```

Then write controllers like you always have:

```ruby
class PizzasController < ApplicationController
  def index
    @pizzas = Pizza.all
  end

  def create
    @pizza = Pizza.create(name: params[:pizza][:name])
    redirect_to pizza_path(@pizza)
  end

  def show
    @pizza = Pizza.find(params[:id])
  end

  def destroy
    Pizza.find(params[:id]).destroy
    redirect_to pizzas_path
  end
end
```

```erb
<%= form_with(model: @pizza) do |f| %>
  <%= f.text_field :name %>
  <%= f.submit %>
<% end %>
```

`Pizza.create`, `Pizza.find`, `Pizza.all`, `pizza.update`, `pizza.destroy`, `pizza.toppings.create` — it feels like ActiveRecord, but it's your pure domain. Tests run against memory adapters automatically. No database setup needed.

## Install

```
gem install hecks
```

## Quick Start

```
hecks new pizzas
cd pizzas
```

This creates a `domain.rb` file:

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String

    validation :name, presence: true

    command "CreatePizza" do
      attribute :name, String
    end
  end
end
```

Validate and build:

```
hecks validate
hecks build
```

This generates `pizzas_domain/` — a complete Ruby gem you can publish or add to any application's `Gemfile`. Each build auto-stamps a CalVer version like `2026.03.20.1`.

## The Domain DSL

### Aggregates

Aggregates are the top-level boundaries. Each aggregate becomes a class in the generated gem with identity-based equality and an auto-generated UUID. All constructor arguments default to nil (or `[]` for lists), like ActiveRecord — validations enforce required-ness, not the constructor.

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    attribute :description, String
    attribute :toppings, list_of("Topping")
    attribute :price, Float
  end
end
```

### Value Objects

Immutable objects defined within an aggregate. They use value-based equality and are frozen on creation.

```ruby
aggregate "Pizza" do
  attribute :toppings, list_of("Topping")

  value_object "Topping" do
    attribute :name, String
    attribute :amount, Integer

    invariant "amount must be positive" do
      amount > 0
    end
  end
end
```

### Commands

Commands describe intent. Each command automatically infers a corresponding domain event (`CreatePizza` -> `CreatedPizza`, `AddTopping` -> `AddedTopping`). Commands are mapped to short method names on aggregate classes by stripping the aggregate name:

- `CreatePizza` -> `Pizza.create(name:, description:)`
- `PlaceOrder` -> `Order.place(pizza_id:, quantity:)`
- `AddTopping` -> `Pizza.add_topping(...)`

```ruby
aggregate "Pizza" do
  command "CreatePizza" do
    attribute :name, String
    attribute :description, String
  end

  command "AddTopping" do
    attribute :pizza_id, reference_to("Pizza")
    attribute :topping, String
  end
end
```

### Validations & Invariants

Validations run on aggregate construction. Invariants enforce business rules on value objects and aggregates.

```ruby
aggregate "Pizza" do
  attribute :name, String
  attribute :price, Float

  validation :name, presence: true
  validation :price, type: Float

  invariant "price must be positive" do
    price > 0
  end
end
```

### Policies

Reactive rules that bind events to commands. When an event fires, the policy declares what command should be triggered. Policies are the approved mechanism for cross-context communication.

```ruby
aggregate "Order" do
  attribute :pizza_id, reference_to("Pizza")
  attribute :quantity, Integer

  command "PlaceOrder" do
    attribute :pizza_id, reference_to("Pizza")
    attribute :quantity, Integer
  end

  policy "ReserveIngredients" do
    on "PlacedOrder"
    trigger "ReserveStock"
  end
end
```

### Cross-Aggregate References

References between aggregates must be by ID only. This is enforced at build time.

```ruby
aggregate "Order" do
  attribute :pizza_id, reference_to("Pizza")  # ID reference, not a direct object
end
```

### Bounded Contexts

Group related aggregates into bounded contexts. Contexts enforce separation — aggregates in different contexts cannot reference each other directly, only through events and policies.

```ruby
Hecks.domain "Pizzas" do
  context "Ordering" do
    aggregate "Order" do
      attribute :pizza_id, reference_to("Pizza")
      attribute :quantity, Integer

      command "PlaceOrder" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer
      end
    end

    aggregate "Pizza" do
      attribute :name, String

      command "CreatePizza" do
        attribute :name, String
      end
    end
  end

  context "Kitchen" do
    aggregate "Recipe" do
      attribute :name, String
      attribute :prep_time, Integer

      command "CreateRecipe" do
        attribute :name, String
        attribute :prep_time, Integer
      end

      # Cross-context communication via events
      policy "StartPrep" do
        on "PlacedOrder"
        trigger "CreateRecipe"
      end
    end
  end
end
```

Domains without `context` blocks work exactly as before — aggregates go into an implicit default context.

## DDD Validation Rules

Hecks enforces DDD best practices at validation time (`hecks validate`, `session.validate`, `session.play!`, `session.build`):

| Rule | What it catches |
|---|---|
| **Aggregates must have commands** | A data bag with no behavior |
| **Command names must be verbs** | `PizzaData` instead of `CreatePizza` |
| **Commands must have attributes** | Empty commands with no payload |
| **No self-references** | An aggregate referencing itself by ID |
| **No bidirectional references** | Pizza -> Order and Order -> Pizza |
| **No cross-context references** | Direct `reference_to` across context boundaries |
| **References must target aggregate roots** | Referencing a value object instead of an aggregate |
| **Value objects must not hold references** | Identity references in a value-only object |
| **No aggregate/value object name collisions** | A value object named the same as its aggregate |
| **Policy events must exist** | Policy listening for an event that no command produces |
| **Policy triggers must exist** | Policy triggering a command that doesn't exist |
| **No duplicate names** | Duplicate aggregate or context names |

In the REPL, bidirectional references are warned about immediately when you add the offending attribute. All other rules are checked at transition points (validate, play, build, save).

## Generated Gem

Running `hecks build` produces a gem with this structure:

### Single Context

```
pizzas_domain/
  lib/
    pizzas_domain.rb                         # entry point + autoloads
    pizzas_domain/
      pizza/
        pizza.rb                             # aggregate root
        topping.rb                           # value object
        commands/
          create_pizza.rb
        events/
          created_pizza.rb
      order/
        order.rb
        commands/
          place_order.rb
        events/
          placed_order.rb
        policies/
          reserve_ingredients.rb
      ports/
        pizza_repository.rb                  # interface
        order_repository.rb
      adapters/
        pizza_memory_repository.rb           # default in-memory adapter
        order_memory_repository.rb
  spec/
    ...
  pizzas_domain.gemspec
```

### Multiple Contexts

```
pizzas_domain/
  lib/
    pizzas_domain.rb
    pizzas_domain/
      ordering/                              # context directory
        order/
          order.rb                           # PizzasDomain::Ordering::Order
          commands/place_order.rb
          events/placed_order.rb
        pizza/
          pizza.rb                           # PizzasDomain::Ordering::Pizza
      kitchen/                               # context directory
        recipe/
          recipe.rb                          # PizzasDomain::Kitchen::Recipe
      ports/
        ordering/
          order_repository.rb
        kitchen/
          recipe_repository.rb
      adapters/
        ordering/
          order_memory_repository.rb
        kitchen/
          recipe_memory_repository.rb
```

### Namespacing

Single context:
```
Pizza                                        # hoisted to top level
Pizza::Topping                               # value object
Pizza::Commands::CreatePizza                 # command
Pizza::Events::CreatedPizza                  # domain event
```

Multiple contexts:
```
Ordering::Order                              # context modules hoisted
Ordering::Pizza
Kitchen::Recipe
```

### Using the Generated Gem

```ruby
require "pizzas_domain"

# Create an aggregate
pizza = PizzasDomain::Pizza.new(name: "Margherita")
pizza.id   # => "a3f2..."
pizza.name # => "Margherita"

# Value objects are frozen
topping = PizzasDomain::Pizza::Topping.new(name: "Mozzarella", amount: 2)
topping.frozen? # => true

# Commands are immutable data
cmd = PizzasDomain::Pizza::Commands::CreatePizza.new(name: "Pepperoni")
cmd.frozen? # => true

# Use the default memory adapter — works out of the box
repo = PizzasDomain::Adapters::PizzaMemoryRepository.new
repo.save(pizza)
repo.find(pizza.id)  # => the pizza
repo.all             # => [pizza]
repo.count           # => 1
repo.delete(pizza.id)
```

## Hecks Services

The application services layer. Wires your domain to adapters, dispatches commands, publishes events, and executes policies. Commands are automatically mapped to short method names on aggregate roots.

### Application Container

```ruby
require "pizzas_domain"
require "hecks"

app = Hecks::Services::Application.new(domain)
```

Every aggregate gets a memory repository by default. Commands become short methods on the aggregate class, and repository methods are available directly:

```ruby
# Commands are mapped to short aggregate class methods
Pizza.create(name: "Margherita", description: "Classic")
# => dispatches CreatePizza command, fires CreatedPizza event, saves to repo, returns pizza

Order.place(pizza_id: "abc-123", quantity: 2)
# => dispatches PlaceOrder, fires PlacedOrder, triggers policies, saves, returns order

Pizza.add_topping(pizza_id: "abc-123", topping: "Pepperoni")
# => dispatches AddTopping, fires AddedTopping, saves, returns pizza

# Repository methods on the aggregate class
Pizza.find(id)
Pizza.all
Pizza.count
Pizza.delete(id)

# Subscribe to events
app.on("CreatedPizza") { |event| puts "Made a #{event.name}!" }

# View event log
app.events
```

### Collection Proxies

List attributes with value objects get `.create`, `.delete`, `.count` and all `Enumerable` methods:

```ruby
pizza = Pizza.create(name: "Margherita")

pizza.toppings.create(name: "Mozzarella", amount: 2)
pizza.toppings.create(name: "Basil", amount: 1)
pizza.toppings.count   # => 2
pizza.toppings.each { |t| puts "#{t.name} x#{t.amount}" }
pizza.toppings.delete(topping)
pizza.toppings.clear
```

Collection proxies rebuild the aggregate with the modified collection and save it back to the repository automatically.

### Multiple Contexts

```ruby
app = Hecks::Services::Application.new(domain)

# Context modules hoisted to top level
Ordering::Order.place(pizza_id: "abc", quantity: 3)
Kitchen::Recipe.create(name: "Margherita", prep_time: 15)

# Repository access via context
app["Ordering"]["Order"].all
app["Kitchen"]["Recipe"].find(id)

# Cross-context events work via shared event bus
app.on("PlacedOrder") { |e| puts "Kitchen notified!" }
```

### Swapping Adapters

Override the default memory adapter for any aggregate:

```ruby
# Single context
app = Hecks::Services::Application.new(domain) do
  adapter "Pizza", PizzasDomain::Adapters::PizzaSqlRepository.new(db)
end

# Multiple contexts
app = Hecks::Services::Application.new(domain) do
  adapter "Ordering", "Order", sql_order_repo
  adapter "Kitchen", "Recipe", sql_recipe_repo
end
```

The rest keep using memory. Swap one at a time as you're ready.

### SQL Adapter Generation

Generate SQL schema and adapter classes from your domain:

```
hecks generate:sql
```

This produces:

**db/schema.sql** — CREATE TABLE statements for every aggregate, with join tables for list value objects:

```sql
CREATE TABLE pizzas (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(255),
  description VARCHAR(255),
  price REAL
);

CREATE TABLE pizzas_toppings (
  id VARCHAR(36) PRIMARY KEY,
  pizza_id VARCHAR(36) NOT NULL REFERENCES pizzas(id),
  name VARCHAR(255),
  amount INTEGER
);
```

**SQL adapter per aggregate** with `find`, `save`, `delete`, `all`, and `count`. Value objects in list attributes are automatically persisted to and loaded from their join tables.

### Rails Integration

Hecks auto-detects Rails projects. `hecks console` adapts its behavior automatically — no separate Rails commands needed.

#### Setup

```ruby
# Gemfile
gem "hecks"
gem "pizzas_domain", path: "./pizzas_domain"

# config/initializers/hecks.rb
require "hecks/rails"
Hecks::Rails.activate(PizzasDomain)

DOMAIN = eval(File.read(Rails.root.join("domain.rb")))
APP = Hecks::Services::Application.new(DOMAIN)
```

#### Rails Generators

```bash
# Copy domain classes into app/models/ and create initializer
rails generate hecks:init

# Reset model files back to pure domain versions
rails generate hecks:clean
```

#### session.apply!

From the console or scripts, `session.apply!` writes domain objects to `app/models/` with a marker comment. Custom methods you add below the marker survive re-applies:

```ruby
session = Hecks.session("Pizzas")
pizza = session.aggregate("Pizza")
pizza.add_attribute :name, String
pizza.add_command("CreatePizza") { attribute :name, String }

session.apply!
#   updated app/models/pizza.rb
#   Applied 1 model files
```

The generated model file includes a marker:

```ruby
# Generated by Hecks from pizzas_domain
# Local modifications are OK — add custom methods below the marker.
# Run `rails generate hecks:clean` to reset to the pure domain version.
#
# ... generated code ...

# --- Custom methods below this line ---

# Your custom methods here are preserved on re-apply
```

#### Migration Strategy System

When you call `session.apply!`, Hecks diffs the old domain (from `domain.rb`) against the new domain and runs registered migration strategies. The built-in `SqlStrategy` generates `ALTER TABLE` / `CREATE TABLE` statements:

```ruby
# Register the SQL strategy (or custom strategies for any backend)
Hecks::MigrationStrategy.register(:sql, Hecks::MigrationStrategies::SqlStrategy)

session.apply!
#   updated app/models/pizza.rb
#   migration db/migrate/20260320143201_hecks_migration.sql
#
# Next steps:
#   Run migration: db/migrate/20260320143201_hecks_migration.sql
#   $ rails db:migrate
#   Restart your Rails server to pick up model changes
```

Custom strategies can be registered for any backend:

```ruby
class RedisMigrationStrategy < Hecks::MigrationStrategy
  def generate(changes)
    # return migration content or nil
  end

  def file_path
    "db/redis/#{Time.now.strftime('%Y%m%d%H%M%S')}_migration.rb"
  end
end

Hecks::MigrationStrategy.register(:redis, RedisMigrationStrategy)
```

#### Controllers

```ruby
class PizzasController < ApplicationController
  def index
    @pizzas = Pizza.all
  end

  def create
    @pizza = Pizza.create(
      name: params[:pizza][:name],
      description: params[:pizza][:description]
    )
    redirect_to pizza_path(@pizza)
  end
end
```

#### Views

```erb
<%# Views — form_with, link_to, render all work %>
<%= form_with(model: @pizza) do |f| %>
  <%= f.text_field :name %>
  <%= f.submit %>
<% end %>

<%= link_to @pizza.name, pizza_path(@pizza) %>
<%= render @pizzas %>
```

## Interactive Console

Hecks includes a REPL for building and exploring domains interactively.

```
hecks console
```

In a Rails project, `hecks console` auto-detects Rails and adapts behavior (shows `session.apply!` help, writes to `app/models/`).

### Build Mode

Build your domain incrementally using aggregate handles:

```ruby
session = Hecks.session("Pizzas")

pizza = session.aggregate("Pizza")
pizza.add_attribute :name, String
pizza.add_attribute :toppings, pizza.list_of("Topping")

pizza.add_value_object "Topping" do
  attribute :name, String
  attribute :amount, Integer
end

pizza.add_validation :name, presence: true

pizza.add_command "CreatePizza" do
  attribute :name, String
end
#   + command CreatePizza -> CreatedPizza
```

Review what you've built:

```ruby
pizza.describe
# Pizza
#
#   Attributes:
#     name: String
#     toppings: list_of(Topping)
#   Value Objects:
#     Topping (name: String, amount: Integer)
#   Commands:
#     CreatePizza (name: String) -> CreatedPizza
#   Validations:
#     name: presence

pizza.preview           # show the generated Ruby code

session.describe        # full domain overview
session.validate        # check for errors
session.save            # write domain.rb
session.build           # generate the gem (CalVer auto-stamped)
session.apply!          # write to app/models/ with migration diffs
```

Modify aggregates without reopening blocks:

```ruby
pizza.add_attribute :price, Float
pizza.remove_attribute :price
pizza.add_invariant("name can't be blank") { !name.empty? }
```

Bidirectional references are caught immediately:

```ruby
order = session.aggregate("Order")
order.add_attribute :pizza_id, order.reference_to("Pizza")

pizza.add_attribute :order_id, pizza.reference_to("Order")
#   + attribute :order_id, reference_to(Order)
#   !! WARNING: Bidirectional reference detected between Pizza and Order.
#      Order already references Pizza. Aggregates should not reference
#      each other — one side should use events/policies instead.
```

### Bounded Contexts in the REPL

```ruby
session = Hecks.session("Pizzas")

ordering = session.context("Ordering")
order = ordering.aggregate("Order")
order.add_attribute :quantity, Integer
order.add_command("PlaceOrder") { attribute :quantity, Integer }

kitchen = session.context("Kitchen")
recipe = kitchen.aggregate("Recipe")
recipe.add_attribute :name, String
recipe.add_command("CreateRecipe") { attribute :name, String }

ordering.describe
kitchen.describe
session.describe        # shows all contexts
```

### Play Mode

Switch to play mode to exercise your commands and see events fire:

```ruby
session.play!

session.commands
# => ["CreatePizza(name: String) -> CreatedPizza",
#     "PlaceOrder(pizza_id: Pizza, quantity: Integer) -> PlacedOrder"]

session.execute("CreatePizza", name: "Pepperoni")
# Command: CreatePizza
#   Event: CreatedPizza
#     name: "Pepperoni"
#     occurred_at: 2026-03-20 14:32:01

session.execute("PlaceOrder", pizza_id: "abc-123", quantity: 3)
# Command: PlaceOrder
#   Event: PlacedOrder
#     pizza_id: "abc-123"
#     quantity: 3
#     occurred_at: 2026-03-20 14:32:05
#   Policy: ReserveIngredients -> ReserveStock

session.events              # all fired events
session.events_of("CreatedPizza")  # filter by type
session.history             # numbered timeline
session.reset!              # clear and start over

session.build!              # back to build mode
```

### Exit Summary

When leaving the REPL, Hecks shows pending actions:

```
Next steps:
  Run migration: db/migrate/20260320143201_hecks_migration.sql
  $ rails db:migrate
  Restart your Rails server to pick up model changes
```

Or if you have unsaved changes:

```
You have unsaved changes. Run session.apply! to update model files.
```

## CLI Reference

| Command | Description |
|---|---|
| `hecks new NAME` | Create a new domain project |
| `hecks build` | Generate the domain gem (CalVer auto-stamped, e.g. `2026.03.20.1`) |
| `hecks validate` | Validate the domain definition |
| `hecks generate:sql` | Generate SQL schema and adapters |
| `hecks version` | Show current domain version |
| `hecks console` | Start interactive REPL (auto-detects Rails) |
| `hecks console NAME` | Start REPL with a new named session |

## Simple API

For scripting or programmatic use:

```ruby
require "hecks"

domain = Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

Hecks.validate(domain)                        # => [true, []]
Hecks.preview(domain, "Pizza")                # => generated Ruby source
Hecks.build(domain, version: "2026.03.20.1")  # => "./pizzas_domain"
```

## Architecture

Hecks has three layers:

**1. Hecks CLI** — The generator tool. Reads a Ruby DSL and produces pure domain gems with CalVer versioning.

**2. Generated Domain Gem** — Pure Ruby, zero dependencies, built-in `autoload`. Contains aggregates, value objects, commands, events, policies, port interfaces, and default memory adapters. This is the artifact your applications depend on.

**3. Hecks Services** — The application runtime. Wires domains to adapters, dispatches commands, publishes events, executes policies. Maps commands to short aggregate class methods. Provides collection proxies for list attributes. Defaults to memory adapters. Optionally generates SQL adapters for persistence.

**4. DomainDiff + MigrationStrategy** — Compares domain snapshots to detect structural changes (add/remove aggregates, attributes, value objects). Feeds changes to registered migration strategies that generate backend-specific migration files.

```
 domain.rb          hecks build         pizzas_domain gem
 (DSL definition) ──────────────────> (pure Ruby, CalVer)
                                              |
                                              v
                                    Hecks::Services::Application
                                    (command dispatch, event bus,
                                     adapter wiring, policies,
                                     collection proxies)
                                              |
                                              v
                                        Adapters
                                    (memory, SQL, custom)

 session.apply!  ─────> DomainDiff ─────> MigrationStrategy
                         (changes)         (SQL, custom backends)
```

### Design Principles

- **Domain purity** — Generated gems have zero runtime dependencies. No framework coupling.
- **Feels like Ruby** — `Pizza.create(name: "Margherita")`, `pizza.toppings.create(...)`, `Pizza.find(id)`. ActiveRecord-style API, DDD structure.
- **Batteries included** — Memory adapters work out of the box. SQL is one command away.
- **DDD rules enforced** — 12 validation rules catch modeling mistakes at build time.
- **CalVer versioning** — Every build auto-stamps `YYYY.MM.DD.N`. No manual bumping. The version tells you when the domain was defined.
- **Bounded contexts** — Group aggregates into contexts. Cross-context communication via events only.
- **Aggregate boundaries** — Cross-aggregate references are by ID only, enforced at build time.
- **Immutability** — Value objects are frozen. Commands and events are frozen.
- **Identity equality** — Aggregates compare by ID. Value objects compare by attributes.
- **Versioned artifacts** — Every build produces a new CalVer version. Your domain is a dependency, not a directory.
- **No hand-editing** — Edit the DSL, rebuild. The generated code is the build output, not the source.
- **Swap when ready** — Start with memory, generate SQL when you need it, bring your own adapter whenever.
- **Optional constructor args** — Aggregate constructors default all attributes to nil. Validations enforce required-ness, not the constructor.

## Project Structure

```
hecks/
  lib/
    hecks.rb                          # entry point + top-level API
    hecks/
      cli.rb                          # Thor CLI
      session.rb                      # interactive REPL session
      aggregate_handle.rb             # per-aggregate mutation API
      context_handle.rb               # per-context REPL handle
      playground.rb                   # play mode runtime
      validator.rb                    # DDD validation rules
      versioner.rb                    # CalVer management (YYYY.MM.DD.N)
      utils.rb                        # shared utilities
      domain_diff.rb                  # compares domain snapshots
      migration_strategy.rb           # base class for migration generators
      dsl_serializer.rb               # domain -> DSL source serializer
      console_runner.rb               # IRB launcher with Rails detection
      rails.rb                        # ActiveModel integration
      railtie.rb                      # Rails auto-detection
      domain_model/                   # intermediate representation
        domain.rb
        bounded_context.rb
        aggregate.rb
        value_object.rb
        attribute.rb
        command.rb
        domain_event.rb
        policy.rb
        validation.rb
        invariant.rb
      dsl/                            # DSL builders
        domain_builder.rb
        context_builder.rb
        aggregate_builder.rb
        value_object_builder.rb
        command_builder.rb
        policy_builder.rb
        attribute_collector.rb
        aggregate_rebuilder.rb
      generators/                     # code generators
        context_aware.rb
        domain_gem_generator.rb
        aggregate_generator.rb
        value_object_generator.rb
        command_generator.rb
        event_generator.rb
        policy_generator.rb
        port_generator.rb
        memory_adapter_generator.rb
        sql_adapter_generator.rb
        sql_migration_generator.rb
        autoload_generator.rb
        spec_generator.rb
      services/                       # application runtime
        application.rb
        command_runner.rb
        event_bus.rb
        collection_proxy.rb
      validation_rules/               # individual DDD rule objects
        base_rule.rb
        aggregates_have_commands.rb
        command_naming.rb
        commands_have_attributes.rb
        name_collisions.rb
        no_bidirectional_references.rb
        no_self_references.rb
        no_value_object_references.rb
        unique_aggregate_names.rb
        unique_context_names.rb
        valid_policy_events.rb
        valid_policy_triggers.rb
        valid_references.rb
      migration_strategies/           # backend-specific migration generators
        sql_strategy.rb
  lib/generators/                     # Rails generators
    hecks/
      init_generator.rb
      clean_generator.rb
  examples/
    pizzas/                           # basic domain example
    rails_app/                        # Rails integration example
  spec/
    ...
```

## License

MIT
