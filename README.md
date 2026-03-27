<p align="center">
  <img src="hecks_logo.png" width="200" height="200" alt="Hecks">
</p>

# What the Hecks?!

**In the world of AI, specification is king.**

Hecks is a domain framework that validates your business model against DDD rules at build time, enforces bounded context boundaries through ports, and generates a portable Ruby gem from a 30-line DSL file. The generated gem has zero framework dependencies -- it runs in Rails, Sinatra, a script, or a test, unchanged.

These aren't things you prompt for. They're compile-time guarantees: no circular references between aggregates, no commands without verb-phrase names, no value objects holding cross-aggregate references, no bidirectional coupling. Twelve rules, checked before a single line of code is generated. Every violation comes with a fix suggestion.

```ruby
hecks(scratch sketch)> aggregate "Cat"
=> #<Cat (0 attributes, 0 commands)>

hecks(scratch sketch)> Cat.attr :name
hecks(scratch sketch)> Cat.command("Adopt") { attribute :name }
  + command Adopt -> Adopted

hecks(scratch play)> Cat.adopt(name: "Whiskers")
Command: Adopt
  Event: Adopted
    name: "Whiskers"

hecks(scratch play)> Cat.count
=> 1
```

Sketch a domain in the REPL. Play with live objects. Watch events fire and policies trigger. When it's right, `hecks build` generates a versioned gem with specs, ports, adapters, and documentation. Swap in SQLite, Postgres, or MySQL with one line. Serve it over HTTP or MCP with another. The domain never changes.

```bash
# Serve it over HTTP — auto-generates REST routes from your commands and queries
$ hecks serve

# Expose it as an MCP server — AI agents get typed tools for every command
$ hecks mcp

# Generate a Sinatra app — CRUD routes, named queries, config, ready to edit
$ hecks generate sinatra && cd cats_domain_app && ruby app.rb
```

REPL sketch → play with live objects → serve over HTTP → expose via MCP → generate a Sinatra app. All the same domain, zero code changes.

---

**Table of Contents**

- [Quick Start](#quick-start)
- [The Seam](#the-seam)
- [The DSL](#the-dsl)
- [What Gets Generated](#what-gets-generated)
- [How the Runtime Wires It Together](#how-the-runtime-wires-it-together)
- [Play Mode](#play-mode)
- [Querying](#querying)
- [Event-Driven Policies](#event-driven-policies)
- [Build-Time Validation](#build-time-validation)
- [Extensions](#extensions)
- [One-Line SQL](#one-line-sql)
- [Rails Integration](#rails-integration)
- [CLI Commands](#cli-commands)
- [Banking Example](#banking-example)
- [AI-Native](#ai-native)
- [How Hecks Compares](#how-hecks-compares)
- [Why Not Just Have AI Generate the Code?](#why-not-just-have-ai-generate-the-code)

More: [Specifications](docs/content/specifications.md) | [Policies](docs/usage/policy_conditions.md) | [Domain-Level Policies](docs/usage/domain_level_policies.md) | [Error Messages](docs/usage/error_messages.md) | [All Features](FEATURES.md)

---

## Quick Start

```
$ gem install hecks
$ hecks new banking
$ cd banking
$ ruby app.rb
```

One command scaffolds the project. `Hecks.boot(__dir__)` does the rest -- loads, validates, generates, and wires everything.

### Developing with Claude Code

`hecks claude` starts file watchers and launches Claude Code with dangerously-skip-permissions:

```bash
$ hecks claude
```

## The Seam

A domain has a boundary. **Ports are the only way through it.**

```ruby
# Inside the boundary — pure business intent
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

# Outside the boundary — infrastructure plugged in via ports
PizzasDomain.persist_to(:sqlite)
PizzasDomain.port(DeliveryDomain)
PizzasDomain.port(:notifications, SendgridAdapter.new)
```

The domain knows nothing about databases, HTTP, or other services. It only knows about commands, events, and business rules.

Three interfaces, one concept:

- **Class methods** -- the outside world commands the domain: `Pizza.create(name: "Margherita")`
- **Instance methods** -- domain objects talk to each other: `pizza.add_topping(...)`
- **Ports** -- the domain reaches the outside world: events, persistence, other domains

A port is just a block of code plugged into a named slot:

```ruby
PizzasDomain.port(:notifications) do |event|
  Sendgrid.send(to: event.email, body: "Your pizza is ready")
end
```

No adapter class needed unless you want one. Persistence is a port. Notifications is a port. Another domain is a port. Tenancy is a port. Everything outside the boundary is a port.

### Cross-Domain Communication

Domains never call each other's commands. They subscribe to each other's events through ports:

```ruby
PizzasDomain.port(DeliveryDomain)   # Pizza events visible to Delivery
DeliveryDomain.port(PizzasDomain)   # Delivery events visible to Pizza
```

Pizza emits `PizzaReady`. Delivery reacts with `ScheduleDelivery`. Delivery emits `DeliveryCompleted`. Pizza reacts with `MarkDelivered`. Two domains, zero coupling.

*Know DDD? See [how Hecks maps to DDD patterns](docs/ddd.md).*
*Love hexagonal architecture? See [how Hecks implements ports and adapters](docs/hexagonal.md).*

## The DSL

A domain is defined in a single Ruby file:

```ruby
Hecks.domain "Banking" do
  aggregate "Account" do
    attribute :customer_id, reference_to("Customer")
    attribute :balance, Float
    attribute :account_type, String
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

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :principal, Float
      attribute :rate, Float
    end

    specification "HighRisk" do |loan|
      loan.principal > 50_000 && loan.rate > 10
    end
  end

  policy "DisburseFunds" do
    on "IssuedLoan"
    trigger "Deposit"
    map account_id: :account_id, principal: :amount
  end
end
```

### DSL Building Blocks

| Concept | Purpose |
|---|---|
| **Aggregates** | Core business objects with unique IDs, typed attributes, and commands |
| **Value Objects** | Frozen, immutable details embedded in an aggregate |
| **Entities** | Mutable sub-objects with their own identity (UUID) |
| **Commands** | Intent -- become class methods (`Account.open(...)`) and auto-generate domain events (`OpenedAccount`) |
| **Validations** | Checked at creation time (presence, uniqueness, length, format, custom) |
| **Invariants** | Enforced on aggregate state after every change |
| **Specifications** | Reusable, composable predicates (`and`, `or`, `not`) |
| **Policies** | React to events by triggering other commands, with attribute mapping and conditions |
| **Queries** | Named, chainable query objects (`where`, `order`, `limit`) |
| **Scopes** | Hash conditions or lambda predicates, callable as class methods |
| **Lifecycles** | State machines: `lifecycle :status, default: "draft" { transition "Approve" => "approved" }` |
| **Services** | Orchestrate multiple commands across aggregates via the command bus |

### Attributes and Types

```ruby
attribute :name, String                     # typed
attribute :tags, :string                    # symbol shorthand
attribute :description                      # defaults to String
attribute :toppings, list_of("Topping")     # collection
attribute :account_id, reference_to("Account")  # cross-aggregate reference
attribute :status, String, default: "open"  # with default
```

Supported types: `String`, `Integer`, `Float`, `Boolean`, `JSON`, `Date`, `DateTime`.

## What Gets Generated

`Hecks.build(domain)` generates a complete, installable Ruby gem. For a `Pizzas` domain with a `Pizza` aggregate, you get:

| Generated file | What it is |
|---|---|
| `pizzas_domain/pizza.rb` | Aggregate class with `Hecks::Model` mixin, auto-UUID, timestamps |
| `pizzas_domain/pizza/commands/create_pizza.rb` | Command with full lifecycle: guard -> handler -> call -> persist -> emit -> record |
| `pizzas_domain/pizza/events/created_pizza.rb` | Frozen, immutable event with `occurred_at` timestamp |
| `pizzas_domain/pizza/topping.rb` | Frozen value object with invariant enforcement |
| `pizzas_domain/ports/pizza_repository.rb` | Abstract port interface with `NotImplementedError` stubs |
| `pizzas_domain/adapters/pizza_memory_repository.rb` | Hash-backed in-memory adapter |
| `pizzas_domain/adapters/pizza_sql_repository.rb` | Sequel-based SQL adapter with schema definition |
| `spec/pizza_spec.rb` | Behavioral RSpec specs for attributes, identity, events, invariants |

The generated gem has `hecks` as its only dependency. `require "pizzas_domain"` auto-boots with memory adapters. Override with `PizzasDomain.boot(adapter: :sqlite)` or `HECKS_SKIP_BOOT=1`.

Additional generation features:
- CalVer versioning (YYYY.MM.DD.N) auto-assigned at build time
- OpenAPI, JSON Schema, and glossary docs generated on build
- Custom `call` methods preserved on regeneration
- Generators show a diff when a target file already exists (never silently overwrite)

## How the Runtime Wires It Together

When you call `Hecks.boot(__dir__)`, the framework:

1. Loads `hecks_domain.rb` from your project directory
2. Validates the domain against DDD rules (see [Build-Time Validation](#build-time-validation))
3. Generates the domain gem (to disk or in-memory via `RubyVM::InstructionSequence`)
4. Creates a `Runtime` that wires all ports

### The `.bind()` Pattern

Instead of a DI container, each port is a module with a `.bind` method that injects behavior at runtime:

```ruby
Persistence.bind(Pizza, agg, repo)     # injects find, save, delete, collections
Commands.bind(Pizza, agg, bus, repo)   # injects Pizza.create(...) dispatch
Querying.bind(Pizza, agg)             # injects where, find_by, pluck, scopes
```

Domain classes start completely bare -- just attributes, validations, and invariants. All capabilities are bolted on at boot time. Tests get memory adapters. Production gets Postgres. Same domain code, zero changes.

### In-Memory Compilation

For tests and REPL sessions, Hecks skips the filesystem entirely:

```ruby
RubyVM::InstructionSequence.compile(source, virtual_path).eval
```

Generated source strings compile directly to bytecode. The full test suite (967 specs) runs in under 1 second.

## Play Mode

A Smalltalk-inspired REPL with two modes -- **sketch** (define your domain) and **play** (run it):

```ruby
session = Hecks.session("Demo")
session.aggregate("Cat") do
  attribute :name, String
  command("Adopt") { attribute :name, String }
end

session.play!

whiskers = Cat.adopt(name: "Whiskers")
Cat.adopt(name: "Mittens")

Cat.count              # => 2
Cat.find(whiskers.id)  # => #<Cat name="Whiskers">

whiskers.name = "Sir Whiskers"
whiskers.reset!        # back to "Whiskers"
```

Sketch a domain, play with live objects, watch events fire, see policies trigger -- all interactively. Same API as production.

Features:
- `sketch!` / `play!` toggling between modeling and execution
- Named constants created in the REPL (`aggregate("Cat")` creates `Cat`)
- System browser: `browse` prints a tree of all domain elements
- Real-time event display and policy triggering feedback
- Persistent command history across sessions (`~/.hecks_history`)

## Querying

Every aggregate gets a rich query API through the Querying port:

```ruby
Pizza.where(style: "Classic")                          # filter
Pizza.find_by(name: "Margherita")                      # single record
Pizza.order(:name)                                     # sort
Pizza.where(style: "Classic").or(Pizza.where(style: "Tropical"))  # OR
Pizza.exists?                                          # existence check
Pizza.pluck(:name)                                     # attribute-only
Pizza.sum(:price)                                      # aggregations (sum, min, max, average)
Pizza.delete_all                                       # batch operations
Pizza.where(price: Hecks.gt(15))                       # operators: gt, gte, lt, lte, not_eq, one_of
```

Named queries and scopes defined in the DSL become class methods:

```ruby
query "ByCustomer" do |cid|
  where(customer_id: cid)
end
# => Account.by_customer("cust-123")
```

## Event-Driven Policies

Commands produce events. Policies react to events by triggering other commands. This is how aggregates communicate without coupling:

```ruby
policy "DisburseFunds" do
  on "IssuedLoan"                                  # listen for this event
  trigger "Deposit"                                # fire this command
  map account_id: :account_id, principal: :amount  # translate attributes
  condition { |event| event.status == "approved" } # gate on condition
end
```

The event bus provides:
- In-process pub/sub with subscriptions and wildcard `on_any`
- Re-entrant policy protection (prevents infinite loops)
- Async dispatch via configurable `async { }` block
- Full event history with timestamps

```ruby
app.on("CreatedPizza") { |event| puts event.name }
app.events  # => all events since boot
```

### Port-Based Access Control

Named ports restrict which methods are visible to a consumer:

```ruby
aggregate "Pizza" do
  port :guest do
    allow :find, :all, :where
  end
end
```

Calls through the `:guest` port to `Pizza.create` raise `PortAccessDenied`.

## Build-Time Validation

Hecks validates your domain model before generating anything. Every error includes a fix suggestion.

| Rule | What it checks |
|---|---|
| CommandNaming | Command names start with a verb (verified via WordNet) |
| NameCollisions | Aggregate names don't collide with their own value objects |
| ReservedNames | No Ruby keywords used as attribute or aggregate names |
| UniqueAggregateNames | No duplicate aggregate names within a domain |
| NoBidirectionalReferences | No circular references between aggregates (A->B and B->A) |
| NoSelfReferences | Aggregates don't reference themselves |
| NoValueObjectReferences | Value objects don't contain cross-aggregate references |
| ValidReferences | References point to existing aggregates |
| AggregatesHaveCommands | Every aggregate has at least one command |
| CommandsHaveAttributes | Every command has at least one attribute |
| ValidPolicyEvents | Policy events match existing domain events |
| ValidPolicyTriggers | Policy triggers match existing commands |

[See error message examples.](docs/usage/error_messages.md)

## Extensions

Each cross-cutting concern is a separate extension that auto-wires when present. Add to your Gemfile to wire, remove to unwire -- no code changes.

```ruby
Hecks.register_extension(:sqlite) { |mod, domain, runtime| ... }
```

### Persistence

| Extension | Description |
|---|---|
| `hecks_sqlite` | SQLite persistence via Sequel |
| `hecks_postgres` | PostgreSQL persistence via Sequel |
| `hecks_mysql` | MySQL persistence via Sequel |
| `hecks_cqrs` | Named persistence connections for read/write separation |

### Application Services

| Extension | Description |
|---|---|
| `hecks_auth` | Actor-based authentication and authorization |
| `hecks_tenancy` | Multi-tenant isolation (`Hecks.tenant = "acme"`) |
| `hecks_audit` | Audit trail of every command execution |
| `hecks_logging` | Structured stdout logging with duration |
| `hecks_rate_limit` | Sliding window rate limiting per actor |
| `hecks_idempotency` | Command deduplication by fingerprint |
| `hecks_transactions` | DB transaction wrapping when SQL adapter present |
| `hecks_retry` | Exponential backoff for transient errors |
| `hecks_pii` | PII field annotation and redaction |

### Infrastructure

| Extension | Description |
|---|---|
| `hecks_serve` | Serve a domain over HTTP (REST and JSON-RPC) |
| `hecks_ai` | MCP (Model Context Protocol) server from your domain |

### Domain Connections DSL

```ruby
app = Hecks.boot(__dir__) do
  persist_to :sqlite
  sends_to :notifications, SendgridAdapter.new
  listens_to OtherDomain
end
```

## One-Line SQL

```ruby
app = Hecks.boot(__dir__, adapter: :sqlite)
```

One line. Tables created, adapters wired, data persisted to SQL. Works with SQLite, PostgreSQL, MySQL.

The persistence port supports:
- Repository pattern: `find`, `all`, `count`, `save`, `delete`
- Instance-level: `save`, `destroy`, `update`
- Collection proxies for `list_of` attributes with `create`, `delete`, `each`, `count`
- Automatic reference resolution with lazy loading
- Optional event sourcing with `EventRecorder` and `Aggregate.history(id)` replay
- SQL migrations generated from domain diffs (`NOT NULL` from `presence: true`, `UNIQUE` from `uniqueness: true`)

## Rails Integration

```
$ rails generate active_hecks:init
```

One command sets everything up:
- Detects domain gems in your Gemfile (or local directories)
- Creates initializer with `Hecks.configure`
- Enables ActionCable, creates `cable.yml`, mounts at `/cable`
- Pins Turbo via importmap, adds `turbo_stream_from` to layout
- Wires test helpers into spec/test files

Domain objects work like ActiveRecord in views. Every domain event auto-broadcasts to connected browsers via Turbo Streams -- no custom JavaScript.

```ruby
# config/initializers/hecks.rb
Hecks.configure do
  persist_to :postgres
end
```

[Rails Setup](docs/usage/hecks_on_rails.md) | [HecksLive](docs/usage/hecks_live.md) | [Turbo Streams](docs/usage/turbo_streams.md) | [Generators](docs/usage/rails_generators.md) | [Packaging](docs/usage/packaging.md)

## CLI Commands

| Command | Description |
|---|---|
| `hecks new NAME` | Scaffold a complete project |
| `hecks build` | Validate, version (CalVer), and generate the domain gem |
| `hecks console` | Interactive REPL with sketch and play modes |
| `hecks validate` | Check domain against DDD rules |
| `hecks serve` | Serve domain over HTTP (REST or `--rpc` for JSON-RPC) |
| `hecks mcp` | Start MCP server for AI tool integration |
| `hecks docs` | Swagger UI for a domain's API |
| `hecks dump` | Extract domain artifacts to filesystem |
| `hecks gem` | Build and install the hecks gem |
| `hecks generate sinatra` | Scaffold a Sinatra web app from a domain |
| `hecks init` | Scaffold a new domain in the current directory |
| `hecks list` | List all installed Hecks domain gems |
| `hecks migrations` | Schema migration management |
| `hecks llms` | Generate AI-readable domain summary (llms.txt) |
| `hecks version` | Framework or domain gem version |
| `hecks claude` | Start file watchers and launch Claude Code (see below) |
| `hecks build --static` | Generate a self-contained project with zero hecks dependency |
| `hecks serve --static` | Build and serve with the built-in UI |

## Static Generation

Generate a complete, self-contained Ruby project from your domain definition. The output has **zero runtime dependency on hecks** — it includes its own runtime, HTTP server, UI, and CLI.

```bash
$ hecks build --static
Built pizzas_domain v2026.03.26.1 (static)
  Output: examples/pizzas_static/

$ cd examples/pizzas_static
$ bin/pizzas serve
PizzasDomain on http://localhost:9292 (adapter: memory)
```

The generated project includes:
- **HTTP server** with JSON API and HTML UI (WEBrick, no external framework)
- **Port-based access control** — roles enforced at the domain level
- **Client-side validation** from domain rules (fetched as JSON, checked before submit)
- **Filesystem persistence** — JSON files on disk, survives restarts
- **Live reload** — edit domain files, server picks up changes
- **Config page** — switch roles and adapters at runtime
- **CLI** — `serve`, `console`, `generate`, `info`

Two files at the project root:
- `hecks_domain.rb` — the domain DSL (regeneratable)
- `boot.rb` — wiring and config (stable, not overwritten on regenerate)

Edit the DSL, run `bin/pizzas generate`, and the running server picks up changes via live reload.

## AI-Native

Hecks treats AI agents as first-class consumers. Every domain is self-describing — agents don't need documentation, they query the domain directly.

### MCP Server

```bash
$ hecks mcp
```

AI agents get typed tools for every command, query, and repository operation. Tool descriptions include parameter constraints, example values, return shapes, and guard conditions. One call to `describe_domain` returns the entire model as structured JSON — aggregates, commands, policies, and their relationships.

### llms.txt

```bash
$ hecks llms > llms.txt
```

Generates an AI-readable summary: aggregates with types, commands with parameters, policies with trigger conditions, reactive flow chains. `hecks build` also includes an `llms.txt` in every generated domain gem, so any agent working in a project gets instant context.

### Reactive Flows

```ruby
domain.flows
# Flow: Loan Issuance → Disbursement
#   1. IssueLoan (Loan) → IssuedLoan
#   2. [Policy: DisburseFunds] on IssuedLoan → Deposit (Account)
#   3. Deposit (Account) → Deposited

domain.flows_mermaid  # Mermaid sequence diagram
```

Auto-generated from the policy graph. Shows how commands chain through events and policies — the "how things connect" picture that AI agents can't infer from code alone.

### Self-Discoverable HTTP API

```bash
$ hecks serve
# GET /_openapi  → OpenAPI 3.0 spec
# GET /_schema   → JSON Schema definitions
```

AI agents hitting the HTTP API can self-discover every endpoint, parameter type, and response shape without documentation.

### Structured Errors

When commands fail, errors return machine-readable JSON:

```json
{
  "error": "GuardRejected",
  "command": "Withdraw",
  "aggregate": "Account",
  "message": "Insufficient funds",
  "fix": "Check balance before withdrawing"
}
```

AI agents can act on failures programmatically — no string parsing.

### hecks claude

A CLI command that starts background file watchers, then launches Claude Code with `--dangerously-skip-permissions` so it can work autonomously.

```bash
$ hecks claude
Watchers started (PID: 12345)
# Claude Code session opens
```

What it does:

1. Kills any existing watcher processes
2. Starts `watch-all` in the background -- polls every second for `.rb` file changes and runs three watchers:
   - **watch-file-size** -- warns when files approach the 200-line code limit (triggers at 180)
   - **watch-cross-require** -- fails if `require_relative` escapes a component boundary
   - **watch-autoloads** -- warns when a new class/module file isn't registered in `autoloads.rb`
3. Launches `claude --dangerously-skip-permissions`, passing through any extra arguments
4. Cleans up watcher processes when Claude exits

## Banking Example

The `examples/banking/` directory contains a complete domain with four aggregates: Customer, Account, Transfer, and Loan.

```bash
ruby -Ilib examples/banking/app.rb
```

The scenario walks through:

1. **Register** two customers (Alice and Bob)
2. **Open accounts** -- checking and savings for Alice, checking for Bob
3. **Deposit** funds into each account
4. **Withdraw** from checking -- succeeds for $1,500, blocked for overdraft and daily limit
5. **Transfer** $500 from Alice to Bob
6. **Issue a loan** -- $25,000 at 5.25%, auto-disburses to Alice's checking via `DisburseFunds` policy
7. **Make loan payments** -- three payments of $450 reduce the remaining balance
8. **Default a loan** -- triggers `SuspendOnDefault` policy, suspends Bob's customer record
9. **Specifications** -- `HighRisk` checks whether a loan exceeds $50k principal and 10% rate

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

## Governance Example

The `examples/governance/` directory is a complex multi-domain project with 5 bounded contexts and 930 lines of DSL. It exercises every Hecks concept:

- **Compliance** — governance policies, compliance reviews, exemptions, evidence collection
- **Model Registry** — AI model registration, versioning, deployment lifecycle
- **Operations** — incidents, runbooks, escalations, on-call scheduling
- **Identity** — users, roles, permissions, authentication
- **Risk Assessment** — risk scoring, mitigations, audit trails

Cross-domain reactive policies wire the contexts together. Use it as a stress test for generators and static output.

## How Hecks Compares

### Hecks vs. ActiveRecord

| | ActiveRecord | Hecks |
|---|---|---|
| **Center of gravity** | The database | Your business domain |
| **Models** | Inherit from `ActiveRecord::Base` | Generated from a DSL, zero dependencies |
| **Persistence** | Baked into every model | Injected at boot via ports -- swap with one line |
| **State changes** | Direct mutation + callbacks | Commands with guard → handler → persist → emit lifecycle |
| **Events** | `after_save` callbacks (synchronous, tangled) | First-class event bus with reactive policies and async dispatch |
| **Cross-concern communication** | Callbacks, service objects, concerns | Ports -- typed boundaries between domains |
| **Testing without a DB** | Slow; requires schema + migrations | Memory adapter by default -- full suite in < 1 second |
| **Validation** | Runtime only (`validates :name, presence: true`) | Build-time DDD rules + runtime validations and invariants |
| **Code generation** | `rails generate scaffold` (one-off) | `Hecks.build` generates a full gem with specs, events, ports, adapters |
| **Domain portability** | Coupled to Rails and ActiveRecord | Standalone Ruby gem -- works in Rails, Sinatra, plain Ruby, or CLI |
| **Bounded contexts** | None -- one global namespace | Each domain is its own gem with explicit ports |
| **REPL** | `rails console` (full app boot) | Sketch + Play modes -- model and run interactively |
| **DB adapters** | PG, MySQL, SQLite (via AR adapters) | PG, MySQL, SQLite, memory (via Sequel + port injection) |
| **CQRS / read-write split** | Manual | `hecks_cqrs` extension |
| **Schema evolution** | Hand-written migrations | Auto-generated from domain diffs |

ActiveRecord is the fastest path from idea to working CRUD app. Hecks is for when you want the domain to outlive the framework -- portable, testable, and explicit about every boundary.

### Why not just have AI generate the code?

AI is good at writing code. It's bad at maintaining constraints across a codebase over time.

Ask Claude to generate a domain layer and you'll get something that works today. Next week, someone adds a bidirectional reference between aggregates. The week after, a command gets named "ProcessData" instead of a verb phrase. A month later, a value object holds a reference to an aggregate root. None of these are bugs -- the code runs fine. They're architectural violations that compound silently until the domain is unmaintainable.

Hecks catches all of these at build time. It's not generating code from a prompt -- it's compiling a formal domain model through 12 DDD validation rules, then generating code that is structurally correct by construction. The generated gem has typed ports, event-driven policies, and bounded context boundaries that can't be bypassed. You can't accidentally couple two domains because the only way through is a port.

Use AI to help you write the DSL. Use Hecks to guarantee the architecture holds.

## License

MIT
