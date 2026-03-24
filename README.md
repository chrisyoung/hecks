# What the Hecks?!

Describe your business in Ruby. Hecks generates the code.

## The Seam

A domain has a boundary. **Ports are the only way through it.**

```ruby
# The domain — pure structure and intent
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

# Ports — how the domain connects to everything else
PizzasDomain.persist_to(:sql)
PizzasDomain.port(DeliveryDomain)
PizzasDomain.port(:notifications, SendgridAdapter.new)
PizzasDomain.port(:tenant, ColumnTenant.new)
```

Three interfaces, one concept:

- **Class methods** — outside world commands the domain: `Pizza.create(name: "Margherita")`
- **Instance methods** — domain objects talk to each other: `pizza.deliver`
- **Ports** — domain reaches the outside world: events, persistence, other domains

Domains don't call each other's commands. They subscribe to each other's events through ports:

```ruby
PizzasDomain.port(DeliveryDomain)   # Pizza events visible to Delivery
DeliveryDomain.port(PizzasDomain)   # Delivery events visible to Pizza
```

Pizza emits `PizzaReady`. Delivery reacts with `ScheduleDelivery`. Delivery emits `DeliveryCompleted`. Pizza reacts with `MarkDelivered`. Two domains, zero coupling.

A port is just a block of code plugged into a named slot:

```ruby
PizzasDomain.port(:notifications) do |event|
  Sendgrid.send(to: event.email, body: "Your pizza is ready")
end
```

No adapter class needed unless you want one. Persistence is a port. Notifications is a port. Another domain is a port. Tenancy is a port. Everything outside the boundary is a port.

*Know DDD? See [how Hecks maps to DDD patterns](docs/ddd.md).*

*Love hexagonal architecture? See [how Hecks implements ports and adapters](docs/hexagonal.md).*

*Using Rails? See [how ActiveHecks bridges domain objects and Rails](docs/active_hecks.md).*

## Quick Start

# hecks new — Scaffold a Project

Create a complete Hecks project in one command.

## Usage

```
$ hecks new banking

Created banking/
  hecks_domain.rb
  app.rb
  Gemfile
  spec/spec_helper.rb
  .gitignore
  .rspec

Get started:
  cd banking
  bundle install
  ruby app.rb
```

## What it generates

**hecks_domain.rb** — starter domain definition:
```ruby
Hecks.domain "Banking" do
  aggregate "Example" do
    attribute :name, String

    command "CreateExample" do
      attribute :name, String
    end
  end
end
```

**app.rb** — one-line boot:
```ruby
require "hecks"

app = Hecks.boot(__dir__)

# Start building:
#   Example.create(name: "Hello")
#   Example.all
```

## Hecks.boot

`Hecks.boot(__dir__)` replaces the manual load/validate/build/require/wire dance:

```ruby
# Before (10 lines):
domain_file = File.join(__dir__, "hecks_domain.rb")
domain = eval(File.read(domain_file), nil, domain_file, 1)
Hecks.validate(domain)
output = Hecks.build(domain, output_dir: __dir__)
$LOAD_PATH.unshift(File.join(output, "lib"))
require "banking_domain"
app = Hecks::Services::Runtime.new(domain)

# After (1 line):
app = Hecks.boot(__dir__)
```

It finds `hecks_domain.rb`, validates, builds the gem, loads it, and returns a Runtime.

## Running

```ruby
require "hecks"
app = Hecks.boot(__dir__)

Example.create(name: "Widget")
Example.create(name: "Gadget")
Example.count  # => 2
Example.all.each { |e| puts e.name }
```

```
Widget
Gadget
```

## The DSL

```ruby
Hecks.domain "Banking" do
  aggregate "Account" do
    attribute :customer_id, reference_to("Customer")
    attribute :balance, Float
    attribute :account_type, String
    attribute :daily_limit, Float
    attribute :status, String, default: "open"
    attribute :ledger, list_of("LedgerEntry")

    entity "LedgerEntry" do
      attribute :amount, Float
      attribute :description, String
    end

    command "OpenAccount" do
      attribute :customer_id, String
      attribute :account_type, String
      attribute :daily_limit, Float
    end

    command "Deposit" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "Withdraw" do
      attribute :account_id, String
      attribute :amount, Float
    end

    validation :account_type, presence: true

    invariant "balance must not be negative" do
      balance >= 0
    end

    specification "LargeWithdrawal" do |withdrawal|
      withdrawal.amount > 10_000
    end

    query "ByCustomer" do |cid|
      where(customer_id: cid)
    end
  end

  aggregate "Loan" do
    attribute :customer_id, reference_to("Customer")
    attribute :principal, Float
    attribute :rate, Float
    attribute :remaining_balance, Float

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :principal, Float
      attribute :rate, Float
    end

    validation :principal, presence: true

    specification "HighRisk" do |loan|
      loan.principal > 50_000 && loan.rate > 10
    end
  end

  # Domain-level policies — cross-aggregate reactions
  policy "DisburseFunds" do
    on "IssuedLoan"
    trigger "Deposit"
    map account_id: :account_id, principal: :amount
  end
end
```

**Aggregates** are the core business objects -- each gets a unique ID, typed attributes, and commands that describe what you can do with them.

**Value objects** (via `value_object`) are frozen details embedded in an aggregate. **Entities** (via `entity`) are mutable sub-objects with their own identity.

**Commands** become class methods: `Account.open(...)`, `Account.deposit(...)`. Each command auto-generates a domain event (`OpenedAccount`, `Deposited`).

**Validations** are checked at creation time. **Invariants** enforce rules on the aggregate's state.

**Specifications** are reusable predicates -- composable with `and`, `or`, `not`.

**Policies** react to events by triggering other commands. `map` translates event attributes to command attributes. `condition` gates when the policy fires.

## Play Mode

# Play Mode Persistence

Play mode now uses a full Runtime with memory adapters. Aggregates are persisted, queryable, and countable after executing commands.

## Usage

```ruby
session = Hecks.session("Demo")
session.aggregate("Cat") do
  attribute :name, String
  command("Adopt") { attribute :name, String }
end

session.play!

# Execute commands — aggregates are persisted
whiskers = session.execute("Adopt", name: "Whiskers")
session.execute("Adopt", name: "Mittens")

# Find, all, count — they work
Cat.find(whiskers.id)   # => #<Cat name="Whiskers">
Cat.all.map(&:name)     # => ["Whiskers", "Mittens"]
Cat.count               # => 2

# Class method shortcuts also persist
Cat.adopt(name: "Shadow")
Cat.count               # => 3

# Reset clears events AND repository data
session.reset!
Cat.count               # => 0
```

## Output

```
Command: Adopt
  Event: Adopted
    name: "Whiskers"

Cat.count: 2
Cat.all: ["Whiskers", "Mittens"]
Cat.find(d67296b0...): Whiskers

Cat.adopt(name: "Shadow"): Shadow
Cat.count: 3

Cleared all events and data
Cat.count: 0
```

## What changed

Play mode previously recorded events but didn't persist aggregates. Now it boots a real `Services::Runtime` with memory adapters, giving you the full command lifecycle: guard, handler, call, persist, emit, record. Same API as production, just in-memory.

## Specifications

Specifications are reusable business predicates defined in the DSL. Each becomes a class with a `satisfied_by?` method.

```ruby
aggregate "Loan" do
  specification "HighRisk" do |loan|
    loan.principal > 50_000 && loan.rate > 10
  end
end

aggregate "Account" do
  specification "LargeWithdrawal" do |withdrawal|
    withdrawal.amount > 10_000
  end
end
```

Use them at runtime:

```ruby
high_risk = Loan::Specifications::HighRisk.new
high_risk.satisfied_by?(loan)  # => true or false
```

Compose specifications with `and`, `or`, and `not`:

```ruby
high_risk = Loan::Specifications::HighRisk.new
large     = Account::Specifications::LargeWithdrawal.new

# Combine with logical operators
risky_and_large = high_risk.and(large)
risky_or_large  = high_risk.or(large)
not_risky       = high_risk.not
```

## Policies

# Policy Conditions

Reactive policies can have a `condition` block that gates when they fire. The block receives the event and must return true for the policy to trigger.

## Usage

```ruby
Hecks.domain "Banking" do
  aggregate "Account" do
    attribute :balance, Float

    command "Withdraw" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "FlagSuspicious" do
      attribute :account_id, String
    end

    # Only flag withdrawals over $10,000
    policy "FraudAlert" do
      on "Withdrew"
      trigger "FlagSuspicious"
      map account_id: :account_id
      condition { |event| event.amount > 10_000 }
    end
  end
end
```

## Behavior

```ruby
# Small withdrawal — policy does NOT fire
Account.withdraw(account_id: acct.id, amount: 500.0)
# => Withdrew event, no FraudAlert

# Large withdrawal — policy fires
Account.withdraw(account_id: acct.id, amount: 25_000.0)
# => Withdrew event
# => Policy: FraudAlert -> FlagSuspicious
```

## No condition = always fires

Policies without a `condition` block fire on every matching event (backward compatible):

```ruby
policy "NotifyOnDeposit" do
  on "Deposited"
  trigger "SendReceipt"
end
# Fires on every Deposited event
```

## Domain-Level Policies

# Domain-Level Policies

Policies that bridge aggregates belong at the domain level, not inside any single aggregate.

## Usage

```ruby
Hecks.domain "Banking" do
  aggregate "Loan" do
    attribute :customer_id, reference_to("Customer")
    attribute :account_id, reference_to("Account")
    attribute :principal, Float

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :account_id, String
      attribute :principal, Float
    end
  end

  aggregate "Account" do
    attribute :balance, Float

    command "Deposit" do
      attribute :account_id, String
      attribute :amount, Float
    end
  end

  # Domain-level: bridges Loan and Account
  policy "DisburseFunds" do
    on "IssuedLoan"
    trigger "Deposit"
    map account_id: :account_id, principal: :amount
  end
end
```

## Output

```
$ ruby -Ilib examples/banking/app.rb

--- Issue loan: $25,000 at 5.25% for 60 months ---
  [event] Deposited $25000.00
  [event] Loan issued: $25000.00 at 5.25%
Alice checking after disbursement: $28000.00
```

The DisburseFunds policy fires when a loan is issued, maps `principal` to `amount`, and triggers a Deposit into the linked account. It lives at the domain level because it coordinates between Loan and Account.

## Conditions work too

```ruby
policy "SuspendOnDefault" do
  on "DefaultedLoan"
  trigger "SuspendCustomer"
  map customer_id: :customer_id
  condition { |event| event.reason != "administrative" }
end
```

## Aggregate-level policies still work

Policies scoped to a single aggregate stay inside the aggregate block. Both levels coexist.

## SQL Persistence

# SQL Adapter Lifecycle

One line to go from domain definition to SQL-backed persistence.

## Usage

```ruby
require "hecks"

# In-memory SQLite (great for development)
app = Hecks.boot(__dir__, adapter: :sqlite)

# File-based SQLite
app = Hecks.boot(__dir__, adapter: { type: :sqlite, database: "banking.db" })

# PostgreSQL (future)
app = Hecks.boot(__dir__, adapter: { type: :postgres, host: "localhost", database: "banking" })
```

## What it does

`Hecks.boot` with an adapter option automatically:
1. Requires Sequel
2. Creates the database connection
3. Generates SQL repository classes for each aggregate
4. Creates tables from the domain IR (columns, types, join tables)
5. Wires everything into a Runtime

## Before and after

```ruby
# Before (30+ lines):
require "sequel"
db = Sequel.sqlite
db.create_table(:accounts) { String :id, primary_key: true; Float :balance; ... }
# ... repeat for every aggregate ...
gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: mod)
eval(gen.generate, TOPLEVEL_BINDING)
# ... repeat for every aggregate ...
app = Hecks::Services::Runtime.new(domain) do
  adapter "Account", AccountSqlRepository.new(db)
  # ... repeat ...
end

# After (1 line):
app = Hecks.boot(__dir__, adapter: :sqlite)
```

## Example

```ruby
require "hecks"
app = Hecks.boot(__dir__, adapter: :sqlite)

Customer.register(name: "Alice", email: "alice@example.com")
Account.open(customer_id: alice.id, account_type: "checking", daily_limit: 5000.0)
Account.deposit(account_id: acct.id, amount: 1000.0)

# Data persists in SQL
Account.count  # => 1
Account.find(acct.id).balance  # => 1000.0
```

## Error Messages

# Error Messages That Teach

Every validation error includes a suggestion for how to fix it.

## Examples

```ruby
domain = Hecks.domain "Test" do
  aggregate "Pizza" do
    attribute :name, String
    # no commands — will fail validation
  end
end

valid, errors = Hecks.validate(domain)
errors.each { |e| puts e }
```

```
Pizza has no commands. Add a command: command "CreatePizza" do attribute :name, String end
```

## More examples

**Bad command name:**
```
Command Data in Pizza doesn't start with a verb. Try 'CreateData' or register
a custom verb with add_verb('Data') or verbs.txt.
```

**Unknown reference:**
```
Reference 'Order' in Pizza.order_id not found. Available aggregates: Customer, Account.
```

**Missing policy event:**
```
Policy NotifyKitchen in Pizza references unknown event: Cooked.
Known events: CreatedPizza, UpdatedPizza.
```

**Missing policy trigger:**
```
Policy NotifyKitchen in Pizza triggers unknown command: Cook.
Available commands: CreatePizza, UpdatePizza.
```

**Bidirectional reference:**
```
Bidirectional reference between Pizza and Order. Remove the reference from
one side — in DDD, only one aggregate should hold the reference. Use a
domain-level policy to coordinate.
```

## Build-Time Checks

| Rule | Description |
|---|---|
| CommandNaming | Rejects command names that do not start with a verb |
| NameCollisions | Rejects aggregate root names that collide with their own value object |
| ReservedNames | Rejects attribute names that are Ruby keywords, and aggregate names |
| UniqueAggregateNames | Rejects duplicate aggregate names within a domain |
| NoBidirectionalReferences | Rejects bidirectional references between aggregates (A->B and B->A) |
| NoSelfReferences | Rejects aggregates that reference themselves |
| NoValueObjectReferences | Rejects reference attributes on value objects |
| ValidReferences | Rejects references to non-existent aggregates and references that |
| AggregatesHaveCommands | Rejects aggregates that have no commands -- an aggregate without |
| CommandsHaveAttributes | Rejects commands that have no attributes |
| ValidPolicyEvents | Produces warnings (not errors) when policies listen for events not defined |
| ValidPolicyTriggers | Rejects policies whose trigger_command does not match any command |

## CLI Commands

| Command | Description |
|---|---|
| `hecks build` | Validates the domain, assigns a CalVer version, and generates the domain gem |
| `hecks console` | Launches an interactive REPL session via Session::ConsoleRunner |
| `hecks docs` | Starts a WEBrick server hosting Swagger UI for a domain's API |
| `hecks dump` | Extracts domain artifacts to the filesystem |
| `hecks gem` | Gem packaging commands — build and install the hecks gem from its gemspec |
| `hecks generate sinatra` | Scaffolds a Sinatra web app from a domain definition |
| `hecks init` | Scaffolds a new Hecks domain in the current directory |
| `hecks list` | Lists all installed Hecks domain gems found via RubyGems, showing |
| `hecks mcp` | Starts an MCP (Model Context Protocol) server |
| `hecks migrations` | Three migration-related subcommands: |
| `hecks new project` | Scaffolds a new Hecks project directory with a domain definition, app.rb, |
| `hecks serve` | Serves a domain over HTTP |
| `hecks validate` | Validates the domain definition and prints a summary of all aggregates, |
| `hecks version` | Shows the Hecks framework version, or the version of a specific domain gem |

## Features

## Domain Modeling DSL
- Define domains with `Hecks.domain "Name" { }` block syntax
- Define aggregates with attributes, commands, events, policies, queries, and scopes
- Define value objects as immutable nested types within aggregates
- Define typed attributes with String, Integer, Float, Boolean, JSON, etc.
- Symbol type shorthand: `:string`, `:integer`, `:float`, `:boolean` resolve to Ruby classes
- Default attribute type is String when omitted
- Define collection attributes with `list_of("Type")` syntax
- Define cross-aggregate references with `reference_to("Aggregate")`
- Define commands with attributes, handlers, guards, read models, actors, and external system docs
- Auto-infer domain events from commands (CreatePizza → CreatedPizza) with irregular verb support
- Define entities within aggregates — sub-objects with identity (UUID), mutable, not frozen
- Define specifications as reusable composable predicates (`satisfied_by?`, `and`, `or`, `not`)
- Define guard policies (authorization blocks that gate command execution)
- Define reactive policies (event-driven: on event → trigger command, with async option)
- Domain-level policies for cross-aggregate concerns (outside any aggregate block)
- Policy conditions: `condition { |event| event.amount > 10_000 }` — policy only fires when true
- Policy attribute mapping: `map principal: :amount` translates event attrs to command attrs
- Define command `call` blocks in DSL for inline business logic (prototyping and play mode)
- Define event subscribers with `on_event` for arbitrary side-effect code on events
- Define named queries with `where`, `order`, `limit`, `offset` chainable DSL
- Define named scopes as hash conditions or lambda predicates
- Define per-attribute validations (presence, uniqueness, length, format, custom)
- Define indexes on aggregates with `index :field` and `index :field, unique: true`
- Define aggregate-level and value-object-level invariants as block constraints
- Define access-control ports that whitelist allowed methods per consumer
- Import domains from event storm formats (Markdown and YAML)
- Multi-domain support with shared event bus across domains
- Domain version pinning and local path loading in configuration

## Runtime API
- `Hecks.boot(__dir__)` — find domain file, validate, build, load, and wire in one call
- `Hecks.boot(__dir__, adapter: :sqlite)` — automatic SQL setup: Sequel connection, adapter generation, table creation
- `Hecks.load(domain)` — load domain and wire runtime in one step, returns `Hecks::Services::Runtime`
- `app["Pizza"]` — access aggregate repository
- `app.on("EventName") { }` — subscribe to events at runtime
- `app.run("CommandName", attrs)` — dispatch commands
- `app.events` — event history
- `app.async { }` — register async handler for policies and subscribers
- `app.use { }` — register command bus middleware

## Code Generation
- Generate complete Ruby gems from domain definitions with `Hecks.build(domain)`
- `Hecks.load(domain)` for fast in-memory eval without writing files (45x faster than build)
- Generate aggregate classes with `Hecks::Model` mixin, auto-UUID, and timestamps
- Generate command classes with full lifecycle (guard → handler → call → persist → emit → record)
- Generate frozen event classes with `occurred_at` timestamps
- Generate entity classes with `Hecks::Model` (UUID, mutable, identity equality)
- Generate specification classes with `Hecks::Specification` mixin (composable predicates)
- Generate query object classes with chainable query builder
- Generate guard and reactive policy classes
- Generate event subscriber classes under `Aggregate::Subscribers`
- Generate frozen value object classes with invariant enforcement
- Generate in-memory repository adapters
- Generate SQL (Sequel-based) repository adapters with schema definitions
- Generate SQL migration files from domain diffs
- Generate behavioral RSpec specs — validations, identity, events, attributes, invariants (not just scaffolds)
- Stacked codegen: constructors, `Aggregate.new(...)`, `attr_reader`, and spec args stack one-per-line when >2 args
- Generate port enforcement stubs
- Generate `require_relative` autoload registries
- Generate complete gem scaffolds (gemspec, lib structure, etc.)
- Preview generated source for any aggregate without writing files
- Auto-include mixins by convention — no explicit `include` lines in generated files
- Auto-generate OpenAPI, JSON-RPC discovery, JSON Schema, and glossary docs on build
- Preserve custom `call` methods on regenerate — generator detects hand-edited logic and keeps it
- CalVer versioning (YYYY.MM.DD.N) auto-assigned at build time
- Resolve domains from installed gems, not just local files

## Persistence
- Memory adapter for fast, zero-setup in-process storage
- SQL adapter via Sequel ORM supporting MySQL, PostgreSQL, and SQLite
- Repository pattern: `find`, `all`, `count`, `save`, `delete` on aggregates
- Instance-level `save`, `destroy`, `update` methods
- Collection proxies for `list_of` attributes with `create`, `delete`, `each`, `count`
- Automatic reference resolution with lazy loading from repository
- Optional event sourcing with `EventRecorder` and `Aggregate.history(id)` replay

## Querying
- `where(field: value)` filtering on aggregates
- `find_by(field: value)` for single-record lookup
- `order(:field)` and `order(field: :desc)` sorting
- OR conditions: `Pizza.where(style: "Classic").or(Pizza.where(style: "Tropical"))`
- `exists?` check without loading all records
- `pluck(:name)` for attribute-only results (single or multi-column)
- Aggregations: `sum(:price)`, `min(:price)`, `max(:price)`, `average(:price)`
- Batch operations: `delete_all`, `update_all(status: "archived")` (bypasses command bus)
- Query operators: `gt`, `gte`, `lt`, `lte`, `not_eq`, `one_of` — pure domain layer, no SQL leakage
- Named scopes callable as class methods (e.g., `Pizza.active`)
- Ad-hoc query support enabled via `include_ad_hoc_queries` config
- ConditionNode tree for composing AND/OR query conditions
- In-memory query executor fallback when adapter lacks `query()` method

## Command & Event System
- Command bus with `app.run("CommandName", attrs)` dispatch
- Short API: `app["Pizza"].create(name: "M")`
- Class-level command methods: `Pizza.create(name: "M")`
- Instance-level command methods: `cat.meow` auto-fills from instance attributes, `cat.meow(name: "Pow")` overrides
- Mutable setters on aggregates — tweak state interactively, then fire commands that read from `self`
- Commands return self with `.aggregate` and `.event` accessors
- `Hecks::Command` mixin orchestrates full lifecycle (guard → handler → call → persist → emit → record)
- `Hecks::Query` mixin — queries are self-contained like commands
- Command bus middleware pipeline (e.g., logging, auth)
- Re-entrant policy protection (skips policies already in-flight)
- In-process event bus with `app.on("EventName") { |event| }` subscriptions
- DSL-defined event subscribers with `on_event "EventName" do |event| ... end`
- Cross-aggregate event subscribers (e.g., Order subscribes to Pizza's CreatedPizza)
- Async subscriber dispatch via configurable `async { }` block (e.g., Sidekiq)
- Async policy dispatch via configurable `async { }` block

## HTTP Servers
- REST server (WEBrick) with auto-generated CRUD routes per aggregate
- Command routes mapped from POST/PATCH to domain commands
- Query routes as `GET /aggregates/query_name?params`
- Event listing endpoint
- CORS support
- JSON request/response serialization
- JSON-RPC 2.0 server with single POST endpoint and proper error codes
- OpenAPI 3.0 spec generation
- JSON Schema generation for all domain types
- JSON-RPC method discovery/registry

## MCP (Model Context Protocol) Server
- Stdio-based MCP server for AI agent integration (`hecks domain mcp`)
- Session tools: create session, load domain from file
- Aggregate tools: add/remove aggregates, attributes, commands, policies
- Inspect tools: describe session overview, describe single aggregate
- Build tools: validate session, build gem, preview aggregate code
- Play tools: enter play mode, execute commands, show events, reset playground
- Domain MCP server: expose commands, queries, and CRUD as MCP tools with input schemas
- Serve domain tool: start HTTP/MCP server from within the MCP session

## CLI Commands
- `hecks new NAME` — scaffold a complete project (domain, app, Gemfile, specs, gitignore)
- `hecks init [NAME]` — top-level shortcut for `hecks domain init`
- `hecks domain build` — validate and generate versioned gem
- `hecks domain serve [--rpc]` — start REST or JSON-RPC server
- `hecks domain console [NAME]` — interactive REPL with domain loaded
- `hecks domain validate` — check domain against DDD rules
- `hecks domain dump` — show glossary, visualizer, and DSL output
- `hecks domain init NAME` — scaffold a new `hecks_domain.rb` template
- `hecks domain list` — show installed domain gems
- `hecks domain mcp` — start MCP server
- `hecks domain generate-sinatra` — scaffold a Sinatra app from domain
- `hecks domain migrations [status|pending|create]` — schema migration management
- `hecks docs update` — sync all file doc headers and READMEs
- `hecks gem build` — build the hecks gem from gemspec
- `hecks gem install` — build and install the hecks gem locally
- `hecks version` / `hecks version DOMAIN` — show framework or domain version
- All commands accept `--domain` flag consistently
- Thor `exit_on_failure?` properly configured

## Session & Playground
- Interactive session for incremental domain building (`Hecks.session`)
- REPL mode via `ConsoleRunner` with `describe`, `validate`, `build`, `play!`, `dump`, `save`
- All session methods hoisted to top level in console (no `session.` prefix needed)
- `_a` shortcut — always points to the last aggregate handle
- `_d` shortcut — always points to the last built domain object
- `help` command in console prints available commands
- Persistent command history across sessions (`~/.hecks_history`)
- Clean IRB exit handling (catches `:IRB_EXIT`)
- AggregateHandle short method names: `attr`, `command`, `validation`, `value_object`, `entity`, `specification`, `policy`, `invariant`, `query`, `scope`, `on_event`, `verb`, `remove`
- Duplicate attribute detection — raises on `attr :name` when `:name` already exists
- `handle.build(**attrs)` — compile domain and return a live domain object instance
- `handle.build` with `active_hecks!` — returns ActiveModel-enhanced instances
- `handle.valid?` — check if aggregate passes DDD validation rules
- `handle.errors` — list validation errors for this aggregate
- `session.active_hecks!` — enable ActiveModel compatibility for all subsequent builds
- `session.add_verb(word)` / `handle.verb(word)` — register custom verbs for command naming validation
- Auto-normalize names to PascalCase (`"cat"` → `"Cat"`, `"adopt cat"` → `"AdoptCat"`)
- Symbol type shorthand in handles: `:string`, `:integer`, `:boolean` resolve to Ruby classes
- Default attribute type is String when omitted (`attr :name` same as `attr :name, String`)
- Play mode compiles domain on the fly with full Runtime (persistence, queries, events, policies)
- Play mode persistence: `Cat.find(id)`, `Cat.all`, `Cat.count`, `Cat.where(...)` all work after executing commands
- Play mode wires command shortcuts onto aggregate classes (`Cat.meow`, `cat.meow`)
- Describe output shows complete aggregate picture: attributes, VOs, entities, commands, validations, invariants, policies, queries, scopes, subscribers, specifications
- `define!` / `play!` toggling — switch between modeling and execution modes
- Real-time event display and policy triggering feedback
- Event history with timestamps, reset/replay capability
- Clean `irb(hecks)` prompt in console
- Suppressed backtraces by default — `backtrace!` / `quiet!` to toggle
- `Hecks::TestHelper` for spec setup and constant cleanup

## Validation & DDD Rules
- No duplicate aggregate names
- References must target aggregate roots
- No bidirectional references between aggregates
- No self-references on aggregates
- Value objects must not contain references
- Aggregates must have at least one command
- Command names must be verb phrases (WordNet + custom verbs via `verbs.txt` or `add_verb`)
- Custom verbs stored on Domain model and checked alongside `verbs.txt`
- Reactive policy events and triggers must reference existing elements
- Aggregate/value-object/entity name collision detection
- Entity references rejected (entities live inside aggregates, not referenced across them)
- Ruby keyword and reserved attribute name detection
- Every validation error includes an actionable fix suggestion

## Migrations & Schema Evolution
- `DomainDiff` detects added/removed aggregates, attributes, value objects, entities, indexes, commands, policies, validations, invariants, queries, scopes, subscribers, and specifications
- `DomainDiff` detects changed policy wiring (event/trigger modifications)
- `MigrationStrategy` dispatches diffs to adapter-specific migration generators
- SQL migration strategy generates Sequel-compatible `db/hecks_migrate/` files
- NOT NULL constraints auto-generated from `validation :field, presence: true`
- UNIQUE constraints auto-generated from `validation :field, uniqueness: true`
- DEFAULT values from `attribute :status, String, default: "draft"`
- Foreign key cascading: `ON DELETE CASCADE` for join tables, `ON DELETE SET NULL` for references
- `CREATE INDEX` / `DROP INDEX` from DSL `index` declarations
- Auto-indexes on reference columns

## Documentation Generation
- Domain glossary: English descriptions of every aggregate, attribute, command, policy, validation, invariant
- Domain visualizer: Mermaid class diagrams (structure) and flowcharts (command → event → policy)
- `Hecks.visualize(domain)` for programmatic Mermaid output
- Domain introspection: `domain.describe`, `domain.glossary`
- DSL serializer: round-trip compiled domain back to DSL source code

## Rails Integration (ActiveHecks)
- `Hecks.configure` block for Rails initializers
- Auto-registers domain gem constants in Rails app
- SQL adapter config with database/host/name options
- Shared event bus across Rails app lifecycle
- Multi-domain support within a single Rails app
- Async dispatch integration (e.g., Sidekiq)
- Domain version pinning and local path loading

## Port & Access Control
- Port system restricts class and instance methods per consumer role
- Raises `Hecks::PortAccessDenied` on unauthorized access
- Configurable whitelists: `allow :find, :all`, etc.

## Architecture
- Hexagonal / ports-and-adapters: domain layer has zero persistence or SQL knowledge
- Operators are pure Specifications (`match?` only) — SQL translation lives in adapters
- Domain gems are the bounded context boundaries
- Constant hoisting promotes aggregates to top-level namespace for convenience
- `Hecks::Model` attribute DSL — no generated constructors, declarative attribute definitions
- `Hecks::Model` generates both readers and writers — mutable for exploration, commands for the record
- `reset!` on aggregate instances — restores all attributes to constructor values, preserves identity
- `CommandMethods.bind_shortcuts` shared between runtime and playground — same `cat.meow` API everywhere

## Self-Documenting README
- `bin/generate-readme` or `hecks docs readme` generates README.md from template
- `docs/readme_template.md` — template with `{{tags}}` for content, usage, features, validation rules, CLI commands
- `docs/content/*.md` — hand-written prose sections
- `docs/usage/*.md` — runnable usage examples
- Auto-generated tables from validation rule and CLI command doc headers
- Missing content files produce `<!-- TODO -->` comments

## Examples
- Pizzas domain: plain Ruby app with commands, queries, collection proxies, event history
- Banking domain: 4 aggregates (Customer, Account, Transfer, Loan), real business logic in generated files, cross-aggregate policies with attribute mapping, specifications, entities, SQLite persistence

## Banking Example

The `examples/banking/` directory contains a complete domain with four aggregates: Customer, Account, Transfer, and Loan. It demonstrates cross-aggregate policies, specifications, entities, and business logic in generated command files.

Run it:

```bash
ruby -Ilib examples/banking/app.rb
```

The scenario:

1. **Register** two customers (Alice and Bob)
2. **Open accounts** -- checking and savings for Alice, checking for Bob
3. **Deposit** funds into each account
4. **Withdraw** from checking -- succeeds for $1,500, blocked for overdraft and daily limit
5. **Transfer** $500 from Alice to Bob -- initiates, then completes
6. **Issue a loan** -- $25,000 at 5.25% for 60 months, auto-disburses to Alice's checking via the `DisburseFunds` policy
7. **Make loan payments** -- three payments of $450 reduce the remaining balance
8. **Default a loan** -- Bob's loan defaults, triggering `SuspendOnDefault` policy which suspends Bob's customer record
9. **Specifications** -- `HighRisk` checks whether a loan exceeds $50k principal and 10% rate

Key output:

```
Alice checking: $5000.00
Blocked: Insufficient funds: balance $3500.0, withdrawal $99999.0
Transfer: completed
Alice checking after disbursement: $28000.00
Loan status: defaulted
Bob status: suspended
Alice's $25k loan high risk? false
Hypothetical $100k/15% loan high risk? true
```

The domain-level policies (`DisburseFunds` and `SuspendOnDefault`) show cross-aggregate event-driven reactions with attribute mapping and conditions.

## License

MIT
