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
  adapter :sql, database: :mysql,
    host: "localhost", user: "root", password: "secret", name: "pizzas"
  include_ad_hoc_queries
end
```

Then write controllers using query objects and familiar methods:

```ruby
class PizzasController < ApplicationController
  def index
    @pizzas = params[:style] ? Pizza.by_style(params[:style]) : Pizza.all
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

## [Why Hecks instead of ActiveRecord?](docs/why_hecks.md)

Hecks was born out of frustration with ActiveRecord. DDD and hexagonal architecture shouldn't be harder than `rails generate model` — so we made it just as easy. Pure domain objects, named queries, any database, no lock-in. [Read more](docs/why_hecks.md).

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

### Queries

Named queries defined in the DSL become class methods on the aggregate. They use the query DSL internally (`where`, `order`, `limit`, comparison operators) but expose a clean domain API.

```ruby
aggregate "Pizza" do
  attribute :name, String
  attribute :style, String
  attribute :price, Float

  query "Classics" do
    where(style: "Classic").order(:name)
  end

  query "ByStyle" do |style|
    where(style: style)
  end

  query "Expensive" do
    where(price: gt(15.0))
  end
end
```

```ruby
Pizza.classics                    # named queries, always available
Pizza.by_style("Tropical")
Pizza.expensive
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

The application services layer, organized into three concerns:

- **Persistence** — `RepositoryMethods`, `CollectionMethods`, `ReferenceMethods` (find, save, create, etc.)
- **Commands** — `CommandBus`, `CommandMethods` (dispatch, event firing)
- **Querying** — `QueryBuilder`, `AdHocQueries`, `ScopeMethods`, `Operators` (where, order, limit, gt, lt)

### Application Container

```ruby
# Plain Ruby — boot manually
require "hecks"
require "pizzas_domain"

domain = eval(File.read("pizzas_domain/domain.rb"))
app = Hecks::Services::Application.new(domain)

# Rails — use the config block
Hecks.configure do
  domain "pizzas_domain"
  adapter :sql, database: :mysql,
    host: "localhost", user: "root", password: "secret", name: "pizzas"
  include_ad_hoc_queries  # opt-in: where, order, limit, find_by
end
```

### Query Objects (always available)

Define named queries in the DSL — they become class methods on the aggregate:

```ruby
aggregate "Pizza" do
  query "Classics" do
    where(style: "Classic").order(:name)
  end

  query "ByStyle" do |style|
    where(style: style)
  end
end
```

```ruby
Pizza.classics                    # => [Margherita, Pepperoni]
Pizza.by_style("Tropical")       # => [Hawaiian]
```

### Ad-Hoc Queries (opt-in)

Enable `include_ad_hoc_queries` for the full ActiveRecord-style API:

```ruby
Pizza.where(style: "Classic")
Pizza.where(price: gt(10)).order(:name)
Pizza.order(:name).limit(5)
Pizza.order(name: :desc).offset(10)
Pizza.find_by(name: "Margherita")
Pizza.limit(10)
Pizza.first
Pizza.last
```

### Persistence Methods

Always available via `RepositoryMethods`:

```ruby
Pizza.find(id)
Pizza.create(name: "Margherita", description: "Classic")
Pizza.all
Pizza.count
Pizza.delete(id)

pizza.save
pizza.update(name: "Margherita Deluxe")
pizza.destroy

pizza.toppings.create(name: "Mozzarella", amount: 2)
pizza.toppings.first.delete

order = Order.place(pizza_id: pizza.id, quantity: 3)
order.pizza  # => resolves the reference
```

### Collection Proxies

List attributes with value objects get `.create`, `.delete`, `.count` and all `Enumerable` methods:

```ruby
pizza = Pizza.create(name: "Margherita")

pizza.toppings.create(name: "Mozzarella", amount: 2)
pizza.toppings.create(name: "Basil", amount: 1)
pizza.toppings.count   # => 2
pizza.toppings.each { |t| puts "#{t.name} x#{t.amount}" }
pizza.toppings.first.delete
pizza.toppings.clear
```

### Adapters

Memory is the default. Switch to SQL with the config block. Hecks uses Sequel under the hood — supports SQLite, MySQL, and Postgres:

```ruby
# Rails — MySQL
Hecks.configure do
  domain "pizzas_domain"
  adapter :sql, database: :mysql,
    host: "localhost", user: "root", password: "secret", name: "pizzas"
  include_ad_hoc_queries
end

# Postgres via URL
Hecks.configure do
  domain "pizzas_domain"
  adapter :sql, url: "postgres://user:pass@host/pizzas"
end

# SQLite (default when no db config)
Hecks.configure do
  domain "pizzas_domain"
  adapter :sql
end

# Plain Ruby — manual wiring with Sequel
require "sequel"
db = Sequel.sqlite("pizzas.db")
app = Hecks::Services::Application.new(domain) do
  adapter "Pizza", PizzasDomain::Adapters::PizzaSqlRepository.new(db)
  adapter "Order", PizzasDomain::Adapters::OrderSqlRepository.new(db)
end
```

Tests always run against memory — fast, isolated, no database. Production uses SQL. The domain code is identical either way.

### Migrations

When using the SQL adapter, Hecks generates migration files to create and update your database schema. Migrations go to `db/hecks_migrate/` — separate from ActiveRecord's `db/migrate/` since these are raw SQL, not AR migrations.

```bash
# First time — generates full CREATE TABLE schema
hecks generate:migrations --domain pizzas_domain

# After updating the domain gem — generates incremental ALTER TABLE
bundle update pizzas_domain
hecks generate:migrations

# Apply to database
hecks db:migrate --database db/app.sqlite3
```

Hecks tracks what domain version your migrations were last generated from by saving a `.hecks_domain_snapshot.rb` file. On each run it diffs the current domain against the snapshot to produce only the changes. First run (no snapshot) generates the full schema.

In Rails, you can also use generators and rake tasks:

```bash
rails generate active_hecks:migration
rake hecks:db:migrate
```

Applied migrations are tracked in a `hecks_schema_migrations` table so they won't run twice.

### Command Bus Middleware

Register middleware that wraps every command dispatch:

```ruby
APP.use :logging do |command, next_handler|
  Rails.logger.info "Command: #{command.class.name}"
  result = next_handler.call
  Rails.logger.info "Event: #{result.class.name}"
  result
end

APP.use :transaction do |command, next_handler|
  ActiveRecord::Base.transaction { next_handler.call }
end
```

Middleware chains like Rack — first registered wraps outermost. If any middleware raises, the command is rejected.

### Multiple Contexts

```ruby
Ordering::Order.place(pizza_id: "abc", quantity: 3)
Kitchen::Recipe.create(name: "Margherita", prep_time: 15)

# Cross-context events work via shared event bus
APP.on("PlacedOrder") { |e| puts "Kitchen notified!" }
```

### Rails Integration

```bash
rails generate active_hecks:init
```

This creates:
- `config/initializers/hecks.rb` — the config block
- `app/models/HECKS_README.md` — explains the empty models folder
- Adds `require "hecks/test_helper"` to your spec_helper

For SQL persistence, generate and run migrations:

```bash
rails generate active_hecks:migration    # generates db/hecks_migrate/*.sql
rake hecks:db:migrate             # applies pending migrations
```

Domain objects work with all Rails helpers — `form_with`, `link_to`, `render`, error display. Tests reset automatically between examples.

## Examples

The `examples/` directory contains runnable demos:

### examples/pizzas/

A standalone Hecks domain with three scripts:

- **`app.rb`** — Full workflow: build gem, boot Application, `Pizza.create`, `pizza.toppings.create`, events, queries
- **`repl_session.rb`** — Interactive domain building with the Session API, then play mode
- **`sql_app.rb`** — SQL adapter generation with a live SQLite demo

```bash
ruby -Ilib examples/pizzas/app.rb
ruby -Ilib examples/pizzas/repl_session.rb
ruby -Ilib examples/pizzas/sql_app.rb
```

### examples/rails_app/

A real Rails 7 app using a Hecks domain gem. Includes controllers, views, routes, the `Hecks.configure` initializer, and the SQL adapter wired for dev/production with memory for tests.

```bash
cd examples/rails_app
bundle install
rails generate active_hecks:init
rails server
```

See `examples/rails_app/README.md` for the full walkthrough.

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
  Run migration: db/hecks_migrate/20260320143201_hecks_migration.sql
  $ hecks db:migrate    (or: rake hecks:db:migrate)
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
| `hecks generate:migrations` | Generate incremental SQL migrations from domain changes |
| `hecks db:migrate` | Run pending Hecks SQL migrations |
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

**4. DomainDiff + MigrationStrategy** — Compares domain snapshots to detect structural changes (add/remove aggregates, attributes, value objects). Feeds changes to registered migration strategies that generate backend-specific migration files to `db/hecks_migrate/`.

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

 hecks generate:migrations ──> DomainDiff ──> MigrationStrategy
   (snapshot vs current)        (changes)      (SQL files to db/hecks_migrate/)
       |
       v
 hecks db:migrate ──> MigrationRunner
   (applies pending .sql files, tracks in hecks_schema_migrations table)
```

### Design Principles

- **Pure domain objects** — Aggregates have no persistence logic. No callbacks, no `belongs_to`.
- **Queries are domain concepts** — Named queries in the DSL, ad-hoc queries opt-in.
- **Any database** — SQLite, MySQL, Postgres via Sequel. One config line to switch.
- **Feels like Ruby** — `Pizza.create(...)`, `Pizza.classics`, `pizza.toppings.create(...)`.
- **Modular services** — Persistence, Querying, Commands are separate mixins.
- **Batteries included** — Memory adapters by default. SQL is one config line away.
- **DDD rules enforced** — 12 validation rules catch modeling mistakes at build time.
- **CalVer versioning** — Every build auto-stamps `YYYY.MM.DD.N`.
- **Immutability** — Value objects, commands, and events are frozen.
- **Swap when ready** — Start with memory, switch to SQL, bring your own adapter.

## Project Structure

```
hecks/
  lib/hecks/
    domain_model/
      behavior/                       # Command, DomainEvent, Policy, Query
      structure/                      # Domain, Aggregate, ValueObject, Attribute, ...
    dsl/                              # DSL builders
    generators/
      context_aware.rb                # shared mixin
      domain/                         # Aggregate, VO, Command, Event, Policy, Query
      sql/                            # SqlAdapter, SqlBuilder, SqlMigration
      infrastructure/                 # Port, MemoryAdapter, Autoload, Spec, DomainGem
    services/
      persistence/                    # RepositoryMethods, CollectionProxy, References
      querying/                       # QueryBuilder, AdHocQueries, Scopes, Operators
      commands/                       # CommandBus, CommandMethods, CommandRunner
      aggregate_wiring.rb             # orchestrates mixin binding
      application.rb                  # boot container
    validation_rules/
      naming/                         # CommandNaming, NameCollisions, Uniqueness
      references/                     # ValidRefs, NoBidirectional, NoSelf, NoVO
      structure/                      # AggregatesHaveCommands, Policies
    migration_strategies/
  active_hecks/                       # Rails integration
  docs/
    why_hecks.md
  examples/
    pizzas/                           # standalone domain example
    rails_app/                        # Rails integration example
```

## License

MIT
