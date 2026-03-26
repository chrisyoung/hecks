# Hecks Framework — Feature List

## Domain Modeling DSL

### Core Structure
- Define domains with `Hecks.domain "Name" { }` block syntax
- Define aggregates with attributes, commands, events, policies, queries, and scopes
- Define value objects as immutable nested types within aggregates
- Define entities within aggregates — sub-objects with identity (UUID), mutable, not frozen
- Multi-domain support with shared event bus across domains
- Domain version pinning and local path loading in configuration

### Attributes & Types
- Define typed attributes with String, Integer, Float, Boolean, JSON, Date, DateTime, etc.
- Symbol type shorthand: `:string`, `:integer`, `:float`, `:boolean`, `:date`, `:datetime`
- Default attribute type is String when omitted
- Define collection attributes with `list_of("Type")` syntax
- Define cross-aggregate references with `reference_to("Aggregate")`

### Commands
- Define commands with attributes, handlers, guards, read models, actors, and external system docs
- Auto-infer domain events from commands (CreatePizza → CreatedPizza) with irregular verb support
- Events carry command attrs + all aggregate attrs by convention — policies can reference any field
- Command `sets` declaration: `sets status: "approved"` — static field assignments
- Define command `call` blocks in DSL for inline business logic (prototyping and play mode)

### State Machines
- Lifecycle DSL: `lifecycle :status, default: "draft" { transition "Approve" => "approved" }`
- Generated status predicates: `model.draft?`, `model.approved?`
- Commands auto-set status to declared target — no hand-editing

### Policies & Events
- Define guard policies (authorization blocks that gate command execution)
- Define reactive policies (event-driven: on event → trigger command, with async option)
- Domain-level policies for cross-aggregate concerns (outside any aggregate block)
- Policy conditions: `condition { |event| event.amount > 10_000 }` — only fires when true
- Policy attribute mapping: `map principal: :amount` translates event attrs to command attrs
- Policy `defaults` for static attribute injection: `defaults entity_type: "AiModel"`
- Define event subscribers with `on_event` for arbitrary side-effect code on events
- Domain-level `on_event` subscribers for cross-aggregate reactions

### Queries & Scopes
- Define named queries with `where`, `order`, `limit`, `offset` chainable DSL
- Define named scopes as hash conditions or lambda predicates

### Specifications & Validation
- Define specifications as reusable composable predicates (`satisfied_by?`, `and`, `or`, `not`)
- Define per-attribute validations (presence, uniqueness, length, format, custom)
- Define indexes on aggregates with `index :field` and `index :field, unique: true`
- Define aggregate-level and value-object-level invariants as block constraints

### Domain Services
- Domain services: `service "TransferMoney" { dispatch "Withdraw"; dispatch "Deposit" }`
- Services orchestrate multiple commands across aggregates via the command bus
- Wired as methods on the domain module: `Banking.transfer_money(...)`

### Access Control & Ports
- Define access-control ports that whitelist allowed methods per consumer
- Import domains from event storm formats (Markdown and YAML)

## Extensions

### Extension Registry
- Extension registry: `Hecks.register_extension(:sqlite) { |mod, domain, runtime| ... }`
- Add to Gemfile to wire, remove to unwire — no code changes needed

### Persistence Extensions
- `hecks_sqlite` — SQLite persistence, auto-wires when in Gemfile
- `hecks_postgres` — PostgreSQL persistence
- `hecks_mysql` — MySQL persistence
- `hecks_cqrs` — named persistence connections for read/write separation

### Server Extensions
- `hecks_serve` registers `:http` — adds `CatsDomain.serve(port: 9292)`
- `hecks_ai` registers `:mcp` — adds `CatsDomain.mcp`

### Application Service Extensions
- `hecks_auth` — actor-based authentication & authorization
- `hecks_tenancy` — multi-tenant isolation (`Hecks.tenant = "acme"`)
- `hecks_audit` — audit trail of every command execution
- `hecks_logging` — structured stdout logging with duration
- `hecks_rate_limit` — sliding window rate limiting per actor
- `hecks_idempotency` — command deduplication by fingerprint
- `hecks_transactions` — DB transaction wrapping when SQL adapter present
- `hecks_retry` — exponential backoff for transient errors

### Domain Connections DSL
- `persist_to :sqlite` — declare persistence adapter in boot block or on domain module
- `sends_to :notifications, adapter` — forward all domain events to an outbound handler
- `sends_to(:audit) { |event| ... }` — forward events to a block handler
- `listens_to OtherDomain` — subscribe to another domain's event bus (cross-domain events)
- `SomeDomain.connections` — inspect current connection configuration
- `SomeDomain.event_bus` — access the domain's event bus for cross-domain wiring
- `Runtime#swap_adapter(name, repo)` — extension gems swap memory adapters for SQL

## Runtime API
- `Hecks.boot(__dir__)` — find domain file, validate, build, load, and wire in one call
- `Hecks.boot(__dir__, adapter: :sqlite)` — automatic SQL setup
- `Hecks.boot(__dir__) { persist_to :sqlite }` — boot block with connections
- `Hecks.load(domain)` — load domain and wire runtime in one step
- `app["Pizza"]` — access aggregate repository
- `app.on("EventName") { }` — subscribe to events at runtime
- `app.run("CommandName", attrs)` — dispatch commands
- `app.events` — event history
- `app.async { }` — register async handler for policies and subscribers
- `app.use { }` — register command bus middleware

## Code Generation

### Auto-Boot
- Generated gems auto-boot: `require "cats_domain"` wires a Runtime with memory adapters
- Generated gems include `hecks` as a dependency and auto-load `hecks_domain.rb`
- Override with `CatsDomain.boot(adapter: :sqlite)` or `HECKS_SKIP_BOOT=1`

### Generated Artifacts
- Generate complete Ruby gems from domain definitions with `Hecks.build(domain)`
- `Hecks.load(domain)` loads domain in memory; file-based or fast in-memory strategy
- Generate aggregate classes with `Hecks::Model` mixin, auto-UUID, and timestamps
- Generate command classes with full lifecycle (guard → handler → call → persist → emit → record)
- Generate frozen event classes with `occurred_at` timestamps
- Generate entity classes with `Hecks::Model` (UUID, mutable, identity equality)
- Generate specification classes with `Hecks::Specification` mixin
- Generate query object classes with chainable query builder
- Generate guard and reactive policy classes
- Generate event subscriber classes under `Aggregate::Subscribers`
- Generate frozen value object classes with invariant enforcement
- Generate in-memory repository adapters
- Generate SQL (Sequel-based) repository adapters with schema definitions
- Generate SQL migration files from domain diffs

### Generation Features
- Behavioral RSpec specs — validations, identity, events, attributes, invariants
- Stacked codegen: constructors stack one-per-line when >2 args
- Port enforcement stubs, autoload registries, gem scaffolds
- Preview generated source for any aggregate without writing files
- Auto-include mixins by convention — `include Hecks::Command` in generated files
- Auto-generate OpenAPI, JSON-RPC discovery, JSON Schema, and glossary docs on build
- Preserve custom `call` methods on regenerate
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
- `pluck(:name)` for attribute-only results
- Aggregations: `sum(:price)`, `min(:price)`, `max(:price)`, `average(:price)`
- Batch operations: `delete_all`, `update_all(status: "archived")`
- Query operators: `gt`, `gte`, `lt`, `lte`, `not_eq`, `one_of`
- Named scopes callable as class methods
- Ad-hoc query support via `include_ad_hoc_queries` config

## Command & Event System
- Command bus with middleware pipeline
- Class-level command methods: `Pizza.create(name: "M")`
- Instance-level command methods: `cat.meow` auto-fills from instance attributes
- `Hecks::Command` mixin orchestrates full lifecycle (guard → handler → call → persist → emit → record)
- `Hecks::Query` mixin — queries are self-contained like commands
- Re-entrant policy protection (skips policies already in-flight)
- In-process event bus with subscriptions and wildcard `on_any`
- Cross-aggregate event subscribers
- Async subscriber and policy dispatch via configurable `async { }` block

## Smalltalk-Inspired REPL

### Sketch & Play
- Interactive session for incremental domain building (`Hecks.session`)
- `sketch!` / `play!` toggling — switch between modeling and execution modes
- Dynamic REPL prompt: `hecks(scratch sketch)`, `hecks(banking play)`

### Named Constants & System Browser
- Named constants: `aggregate("Cat")` creates `Cat` constant in the REPL
- System browser: `browse` prints a tree of all domain elements
- Message not understood: unknown methods suggest creating commands

### Session Features
- All session methods hoisted to top level in console
- AggregateHandle short method names: `attr`, `command`, `validation`, etc.
- Duplicate attribute detection
- `handle.build(**attrs)` — compile domain and return a live domain object
- Auto-normalize names to PascalCase
- Play mode compiles domain on the fly with full Runtime
- Real-time event display and policy triggering feedback
- Event history with timestamps, reset/replay capability
- Suppressed backtraces by default — `backtrace!` / `quiet!` to toggle
- Persistent command history across sessions (`~/.hecks_history`)
- `Hecks::TestHelper` for spec setup and constant cleanup

## Validation & DDD Rules
- No duplicate aggregate names
- References must target aggregate roots
- No bidirectional or self-references on aggregates
- Value objects must not contain references
- Aggregates must have at least one command
- Command names must be verb phrases (WordNet + custom verbs)
- Reactive policy events and triggers must reference existing elements
- Name collision detection across aggregates/VOs/entities
- Ruby keyword and reserved attribute name detection
- Every validation error includes an actionable fix suggestion

## Migrations & Schema Evolution
- `DomainDiff` detects added/removed aggregates, attributes, VOs, entities, indexes, commands, policies, validations, invariants, queries, scopes, subscribers, specifications
- SQL migration strategy generates Sequel-compatible files
- NOT NULL from `validation :field, presence: true`
- UNIQUE from `validation :field, uniqueness: true`
- DEFAULT values from attribute defaults
- Foreign key cascading for join tables and references
- Auto-indexes on reference columns

## Documentation Generation
- Domain glossary with English descriptions
- Mermaid class diagrams and flowcharts
- DSL serializer: round-trip compiled domain back to DSL source code
- README generator with `{{tags}}` for auto-generated sections
- `{{connections}}` tag generates extension gem listing
- `{{smalltalk}}` tag generates Smalltalk features section from `SmalltalkFeatures` metadata

## Gem Architecture
- Core `hecks` gem has zero runtime dependencies
- Each extension is a top-level gem candidate at `lib/`
- `require "hecks"` gives you the core; each extension is a separate require
- Flattened namespace: `Hecks::Runtime`, not `Hecks::Services::Runtime`
- Hexagonal / ports-and-adapters: domain layer has zero persistence knowledge
- Domain gems are the bounded context boundaries

## CLI Commands
- `hecks new NAME` — scaffold a complete project
- `hecks domain build` — validate and generate versioned gem
- `hecks domain serve [--rpc]` — start REST or JSON-RPC server
- `hecks domain console [NAME]` — interactive REPL with domain loaded
- `hecks domain validate` — check domain against DDD rules
- `hecks domain mcp` — start MCP server
- `hecks domain dump` — show glossary, visualizer, and DSL output
- `hecks domain migrations` — schema migration management
- `hecks docs update` — sync doc headers and READMEs
- All commands accept `--domain` flag consistently

## Rails Integration (ActiveHecks)
- `Hecks.configure` block for Rails initializers
- Auto-detects `*_domain` gems in the Gemfile — zero config needed
- Auto-registers domain gem constants in Rails app
- SQL adapter config with database/host/name options
- Multi-domain support within a single Rails app
- Rails generators registered dynamically via Railtie
- `to_param` patched on command results — URL helpers work naturally
- `rails generate active_hecks:init` — one command sets up everything:
  - Adds `hecks_on_rails` to Gemfile
  - Detects domain gems (local directories or installed gems)
  - Creates initializer and app/models/HECKS_README.md
  - Enables ActionCable, creates cable.yml, mounts at /cable
  - Pins Turbo via importmap, adds turbo_stream_from to layout
  - Wires test helpers into spec/test files
- `rails generate active_hecks:live` — standalone live event setup
- `rails generate active_hecks:migration` — SQL migrations from domain changes

## HecksLive — Real-Time Domain Events
- Zero-config real-time event streaming via ActionCable + Turbo Streams
- Every domain event auto-broadcasts to connected browsers
- Railtie wires `event_bus.on_any` → `Turbo::StreamsChannel.broadcast_prepend_to`
- Views just need `<%= turbo_stream_from "hecks_live_events" %>` and `<div id="event-feed">`
- No custom JavaScript — standard Rails Turbo Streams
- Works across page navigations with `data-turbo-permanent`
- Stdout fallback when ActionCable is not available (plain Ruby apps)
- Custom channels via `HecksLive::Channel` subclass with `subscribe_to`

## Packaging
- Core, ActiveModel, real-time, and persistence ship as separate packages
- `hecks_on_rails` bundles everything for Rails apps
- Extensions auto-wire when present — no configuration needed
- See [Packaging](docs/usage/packaging.md) for the full breakdown

## Code Generation — list_of Semantics
- Commands that add to `list_of` collections generate proper append logic
- `AddTopping` command generates `existing.toppings + [Topping.new(name: topping)]`
- `CollectionProxy` supports `+` operator for generated command compatibility

## Examples
- Pizzas domain: plain Ruby app with commands, queries, collection proxies, event history
- Rails pizza shop: full Turbo Streams app with admin, ordering, toppings, pricing, live events
- Banking domain: 4 aggregates, cross-aggregate policies, specifications, entities, SQLite
