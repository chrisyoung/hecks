# Hecks Framework — Feature List

## Domain Modeling DSL
- Define domains with `Hecks.domain "Name" { }` block syntax
- Define aggregates with attributes, commands, events, policies, queries, and scopes
- Define value objects as immutable nested types within aggregates
- Define typed attributes with String, Integer, Float, Boolean, JSON, etc.
- Define collection attributes with `list_of("Type")` syntax
- Define cross-aggregate references with `reference_to("Aggregate")`
- Define commands with attributes, handlers, guards, read models, actors, and external system docs
- Auto-infer domain events from commands (CreatePizza → CreatedPizza) with irregular verb support
- Define guard policies (authorization blocks that gate command execution)
- Define reactive policies (event-driven: on event → trigger command, with async option)
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
- Generate query object classes with chainable query builder
- Generate guard and reactive policy classes
- Generate event subscriber classes under `Aggregate::Subscribers`
- Generate frozen value object classes with invariant enforcement
- Generate in-memory repository adapters
- Generate SQL (Sequel-based) repository adapters with schema definitions
- Generate SQL migration files from domain diffs
- Generate RSpec spec scaffolds per aggregate
- Generate port enforcement stubs
- Generate `require_relative` autoload registries
- Generate complete gem scaffolds (gemspec, lib structure, etc.)
- Preview generated source for any aggregate without writing files
- Auto-include mixins by convention — no explicit `include` lines in generated files
- Auto-generate OpenAPI, JSON-RPC discovery, JSON Schema, and glossary docs on build
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
- `hecks domain list` — show installed domain gems with versions
- `hecks domain dump` — show glossary, visualizer, and DSL output
- `hecks docs update` — sync all file doc headers and READMEs
- `hecks gem build` / `hecks gem install` — package and install domain gems
- `hecks version` / `hecks version DOMAIN` — show framework or domain version
- All commands accept `--domain` flag consistently

## Session & Playground
- Interactive session for incremental domain building (`Hecks.session`)
- REPL mode via `ConsoleRunner` with `describe`, `validate`, `build`, `play!`, `dump`, `save`
- Play mode compiles domain on the fly and executes commands against live in-memory app
- Real-time event display and policy triggering feedback
- Event history with timestamps, reset/replay capability
- `Hecks::TestHelper` for spec setup and constant cleanup

## Validation & DDD Rules
- No duplicate aggregate names
- References must target aggregate roots
- No bidirectional references between aggregates
- No self-references on aggregates
- Value objects must not contain references
- Aggregates must have at least one command
- Command names must be verb phrases
- Reactive policy events and triggers must reference existing elements
- Aggregate/value-object name collision detection
- Ruby keyword and reserved attribute name detection

## Migrations & Schema Evolution
- `DomainDiff` detects added/removed aggregates, attributes, value objects, and indexes
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
