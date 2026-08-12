# hecksagain System Architecture

**Last Updated:** 2026-08-11  
**Status:** Living document - update when architecture changes

---

## Executive Summary

hecksagain is a domain-driven design (DDD) framework where entire domains are declared in `.bluebook` files as data (not code). A single Ruby runtime interprets these files and provides command dispatch, query execution, event recording, and saga/policy orchestration.

**Key Insight:** Nothing is scripted. Invariants, commands, mutations, and lifecycle are all *declared* in the DSL and *interpreted* at runtime.

---

## High-Level Flow

```
.bluebook file (domain declaration)
    ↓
Bluebook DSL parser (language/bluebook/)
    ↓
IR (Intermediate Representation - JSON-like structure)
    ↓
Runtime registry (stores parsed domains)
    ↓
Command/Query dispatch (runtime/)
    ↓
Adapter (persistence layer - Memory, PostgreSQL, SQLite)
    ↓
Aggregate instances + events
```

---

## Directory Structure & Responsibilities

### `/lib/hecksagain/`

#### **bluebook/** - DSL Definition & Parsing
The language itself. Contains:
- `dsl/bluebook_builder.rb` - Entry point for declaring domains
- `dsl/entity_builder.rb` - Value objects and entities DSL
- `meta_validator.rb` - Validates declared bluebooks against constraints
- `syntax.bluebook` - Self-hosted grammar (the bluebook language defined in bluebook)

**You touch this when:** Adding new DSL keywords or constraints

#### **language/** - Language Infrastructure  
Shared language logic across all DSLs (bluebook, world, interview, etc):
- `bluebook/syntax.bluebook` - Core grammar
- Expression parsing and evaluation
- Pattern matching

**You touch this when:** Core language semantics change

#### **runtime/** - The Execution Engine ⚡ CRITICAL
Interprets declared domains and executes commands/queries. Core files:

**Dispatch & Interpretation:**
- `dispatcher.rb` - Main entry point, routes verbs to the right interpreter
- `command_interpreter.rb` - Executes commands (given → mutation → ensures → emit)
- `query_interpreter.rb` - Executes queries, handles filtering/sorting
- `entity_interpreter.rb` - Interprets entities (embedded in aggregates)
- `policy_interpreter.rb` - Handles policies (reactive behaviors)
- `interpreting.rb` - Common interpretation pipeline

**Instance Management:**
- `instance.rb` - Represents a single aggregate instance in memory
- `value.rb` - Wraps value objects with type info
- `value/coercion.rb` - Converts raw args → typed values, validates invariants ⚠️ **HAS KNOWN BUG**
- `identity.rb` - Aggregate identity handling

**Persistence & Queries:**
- `read_model_interpreter.rb` - Read model projections
- `reference_hop.rb` - Dotted path resolution (e.g., `pizza.price_cents.cents`)
- `registry.rb` - Holds all loaded domains

**Errors & Validation:**
- `errors.rb` - Exception hierarchy (GivenNotMet, InvariantViolation, etc.)
- `refusal_wording.rb` - User-friendly error messages

**Advanced:**
- `saga_interpreter.rb` - Long-running sagas (cross-domain orchestration)
- `port_operation_interpreter.rb` - Port invocation from commands
- `era_guard.rb`, `era_check.rb` - Schema evolution support

**🔴 Known Issues in runtime/:**
- `value/coercion.rb:build()` - Doesn't validate invariants on nested value objects
- `instance.rb` - Lists weren't frozen (FIXED in commit 8baa725)

#### **adapters/** - Persistence Implementations
Pluggable storage backends. Each implements:
- `persistence_port.rb` - Interface for saving/loading aggregates
- `extraction_port.rb` - Interface for querying
- `prism_adapter.rb` - In-memory reference implementation

**Available adapters:**
- `memory_adapter.rb` - In-memory storage (for tests, demos)
- Postgres (external)
- SQLite (external)

**You touch this when:** Adding new storage backends or changing persistence contract

#### **facade/** - Public API
User-facing interfaces:

- `boot.rb` - `Hecks.boot(DOMAIN)` entry point
- `handle.rb` - Fluent interface for dispatching commands
- `query_executor.rb` - Query interface

**You touch this when:** Changing how users interact with domains

#### **bluebook/dsl/** - DSL Builder Infrastructure
Internal DSL mechanics:
- `bluebook_builder.rb` - Main builder for `Hecks.bluebook` block
- `entity_builder.rb` - Builds value objects, entities, one_of sets
- `const_shim.rb` - Dynamic constant resolution within DSL context

**You touch this when:** Adding new DSL constructs or keywords

#### **projector/** - Rust/Language Translation
Generates projections to other languages. Contains:

- `exporter.rb` - Exports IR to JSON
- `rust/` - Rust code generation
- `generator.rb` - Base infrastructure

**You touch this when:** Adding new target languages or changing IR contract

#### **translation/** - Schema Evolution
Handles schema changes between eras:

- `plan.rb` - Defines a migration plan
- `audit.rb` - Verifies translation correctness
- `apply.rb` - Applies migrations to data

**You touch this when:** Adding new migration operators or changing how eras work

#### **interview/** - Interview DSL
Separate DSL for defining interview/questionnaire flows:
- `bluebook/interview.bluebook` - Interview grammar
- `syntax.rb` - Interview-specific parsing

**You touch this when:** Extending interview capabilities

#### **doc/** - Documentation Generation
Auto-generates guides and reference docs:
- `doctest_harness.rb` - Runs code examples embedded in markdown
- `generator.rb` - Creates reference documentation

**You touch this when:** Changing how docs are generated

#### **fuzzing/** - Property-Based Testing
Generates random test inputs and validates properties:
- `sequence_generator.rb` - Creates random sequences of commands
- `value_generator.rb` - Generates random test data
- `corpus_executor.rb` - Runs test sequences against domains

**You touch this when:** Adding new generators or validation rules

#### **framework/** - Reusable Domains
Pre-built domains for cross-cutting concerns:

- `bluebook/identity.bluebook` - OIDC/SSO integration
- `bluebook/governance.bluebook` - RBAC role management
- `bluebook/console_settings.bluebook` - UI configuration

**You touch this when:** Adding shared domain patterns

#### **deploy/** - Deployment Automation
Infrastructure as code:

- `bluebook/deploy.bluebook` - Deployment domain
- Generates Terraform, CloudFormation, etc.

**You touch this when:** Adding deployment patterns or cloud targets

#### **ports/** - Port Definitions
Interfaces for external integrations:

- `persistence_port.rb` - How to save/load data
- `extraction_port.rb` - How to query data
- `authentication_port.rb` - How to authenticate users

**You touch this when:** Adding new integration points

#### **presentation/** - UI Rendering
Generates web UIs (via embryonaut_console, hecks_studio):

- Renders forms, tables, detail views
- Integrates with Rust projector

**You touch this when:** Changing how domains render in web UIs

#### **grammar/** - Self-Hosted Grammar
Meta-languages defined in bluebook:
- `bluebook.bluebook` - The bluebook language itself
- `world.bluebook` - Deployment world syntax
- `expression.bluebook` - Expression language

**You touch this when:** Extending the core language

#### **router/** - Request Routing
HTTP/API routing layer:
- Routes requests to domains/commands/queries
- Handles path parameters

**You touch this when:** Adding new routing patterns

#### **query_specification/** - Query DSL
Defines how queries work:
- `field_path.rb` - Dotted path resolution (`pizza.price_cents.cents`)
- Filtering, sorting, limiting

**You touch this when:** Changing query semantics

---

## Key Concepts Map

### The Dispatch Pipeline

When you call `Order.create_pizza(...)`:

1. **Dispatcher** (`runtime/dispatcher.rb`)
   - Parses verb: "Pizzas::Order.CreatePizza"
   - Routes to CommandInterpreter

2. **CommandInterpreter** (`runtime/command_interpreter.rb`)
   - Step 1: Normalize arguments (coerce to types)
   - Step 2: Load existing aggregate (if mutating)
   - Step 3: Check givens (preconditions)
   - Step 4: Apply mutations
   - Step 5: Check ensures (postconditions)
   - Step 6: Emit events
   - Step 7: Save to adapter
   - Returns: Instance with events

3. **Value Coercion** (`runtime/value/coercion.rb`) ⚠️
   - Converts `{ value: "Margherita" }` → `Value(PizzaName)`
   - **BUG:** Doesn't validate invariants on nested VOs
   - Validates patterns (email regex, etc.)

4. **Adapter** (`adapters/`)
   - Persistence: saves aggregate + events
   - Query: fetches aggregates, applies filters

### The Query Pipeline

When you call `Order.available()`:

1. **Dispatcher** routes to QueryInterpreter
2. **QueryInterpreter** (`runtime/query_interpreter.rb`)
   - Fetches all matching aggregates
   - Applies where clauses
   - Applies order_by
   - Applies limit
   - Returns: Array of hashes (rows)

### The Saga Pipeline

When a saga reacts to an event:

1. **Event** emitted by a command
2. **SagaInterpreter** (`runtime/saga_interpreter.rb`)
   - Matches event to saga conditions
   - Dispatches resulting commands (to other domains)
   - Records saga progression
3. Repeat until saga completes

---

## Data Flow Examples

### Creating a Pizza

```
Input: Order.create_pizza(name: {value: "Margherita"}, ...)
  ↓
Dispatcher determines: CommandInterpreter
  ↓
CommandInterpreter.call()
  - Coerce args (name string → PizzaName VO)
  - Load/create Order instance
  - Check givens (always pass on create)
  - Apply mutations (set name, pizza, status)
  - Check ensures (none on create)
  - Emit PizzaCreated event
  - Save to adapter
  ↓
Output: Order instance with id, state, events
```

### Querying Available Pizzas

```
Input: Order.available()
  ↓
Dispatcher determines: QueryInterpreter
  ↓
QueryInterpreter.call()
  - Fetch all Order instances from adapter
  - Filter where status == "available"
  - Sort by name asc
  - Return as Array<Hash>
  ↓
Output: [{ id: "order-1", status: "available", ... }, ...]
```

### Cross-Domain Saga (Example)

```
Event: PizzaPurchased (from Pizzas domain)
  ↓
SagaInterpreter.call(event)
  - Match saga condition: on_pizza_purchased
  - Dispatch: Payments::Invoice.create(...)
  - Wait for InvoiceCreated event
  - Dispatch: Notifications::SendConfirmation(...)
  - Mark saga complete
  ↓
Result: Cross-domain orchestration complete
```

---

## Critical Files for Bug Finding

When testing, pay attention to:

1. **runtime/value/coercion.rb** - Invariant validation (KNOWN BUG)
2. **runtime/instance.rb** - Instance state management (FIXED: lists now frozen)
3. **runtime/command_interpreter.rb** - Mutation logic
4. **runtime/query_interpreter.rb** - Query filtering/sorting
5. **facade/handle.rb** - Public API surface

## Testing Entry Points

- **Corpus tests** (`spec/corpus_spec.rb`) - Domain loading
- **Pizzas tests** (`spec/pizzas_spec.rb`) - Individual domain behavior
- **Banking tests** (`spec/banking_state_machine_spec.rb`) - State machines
- **QA tests** (`qa/qa_adversarial_fixed.rb`) - Adversarial attacks

---

## Architecture Changes Over Time

### Recent Fixes (2026-08-11)
- ✅ List attributes now frozen to prevent state mutation
- ✅ Document nested VO invariant validation gap

### Known Gaps Requiring Changes
- 🔴 Nested VO invariants not validated (requires coercion.rb refactor)
- 🔴 Invalid closed-set values accepted (cascades from above)

### Planned/In Progress
- Rust parser parity (Stage 5 - commit e48226c through)
- Schema evolution tooling
- Cross-domain saga improvements

---

## How to Update This Document

Add an entry under "Architecture Changes Over Time" when:
- A major bug is fixed
- A new module is added
- An existing module's responsibility changes
- A known issue is identified

Keep it as a **living reference** - update immediately when the system changes so future QA work stays accurate.

---

## Complete Bluebook Inventory (2026-08-11 Updated)

### Domain Examples (Testable with Real Data)
1. **Pizzas** - examples/pizzas/bluebook/pizzas.bluebook
   - Status: ✅ Heavily tested (8 categories)
   - Aggregates: Order
   - Value Objects: PizzaName, CustomerName, ToppingName, Pizza, Price, Topping, Size
   - Queries: Available, CostingLessThan, Expensive
   - Key Patterns: Nested VO, lifecycle (available→sold), pricing

2. **Banking** - examples/banking/bluebook/banking.bluebook
   - Status: ⏳ Partially tested (needs comprehensive 8-category testing)
   - Aggregates: Account, Transfer, SafeDepositBox
   - Value Objects: Holder, Price (shared with pizzas), Cents
   - Key Patterns: Composite identity (SafeDepositBox), frozen account checks, daily limits
   - State Violations: Transfer rules, overdraft prevention

3. **Compliance** - examples/compliance/ (STUB - no files yet)
   - Status: ❌ Not implemented
   - Would likely test: Cross-domain sagas, approval workflows, audit trails

### Language & Framework Bluebooks (Meta-Domains)

**Core Language (Critical for parsing all domains):**
- lib/hecksagain/language/bluebook/bluebook.bluebook
- lib/hecksagain/language/bluebook/aggregate.bluebook
- lib/hecksagain/language/bluebook/entity.bluebook
- lib/hecksagain/language/bluebook/behavior.bluebook
- lib/hecksagain/language/bluebook/reaction.bluebook
- lib/hecksagain/language/bluebook/projection.bluebook
- lib/hecksagain/language/bluebook/shape.bluebook
- lib/hecksagain/language/bluebook/syntax.bluebook
- lib/hecksagain/language/bluebook/vocabulary.bluebook
- lib/hecksagain/language/hecksagon.bluebook
- lib/hecksagain/language/world.bluebook

**Sublanguages:**
- lib/hecksagain/grammar/expression.bluebook (predicate language, limited operators)
- lib/hecksagain/grammar/translation.bluebook (era migration language)

**Framework Domains:**
- lib/hecksagain/framework/bluebook/identity.bluebook - OIDC identity + ExternalIdentifier
- lib/hecksagain/framework/bluebook/governance.bluebook - RBAC + RoleAssignment
- lib/hecksagain/framework/bluebook/console_settings.bluebook - Presentation config
- lib/hecksagain/framework/bluebook/interview.bluebook - Language interviews
- lib/hecksagain/deploy/bluebook/deploy.bluebook - Deployment targets + validation

**Presentation Examples:**
- lib/hecksagain/presentation/examples/banking_console.bluebook - Console UI example

### Test Fixtures (Designed for Specific Coverage)
- spec/fixtures/dispatch_order.bluebook - Command execution order
- spec/fixtures/payments.bluebook - Payment saga + port example
- spec/fixtures/settlement.bluebook - Transaction settlement
- spec/fixtures/till.bluebook - Point of sale
- spec/fixtures/reflex.bluebook - Projection reaction chains

**Evolution/Era Tests:**
- spec/fixtures/eras/base.bluebook - Baseline domain
- spec/fixtures/eras/bump_*.bluebook (9 variants) - Schema migration scenarios
- spec/fixtures/eras/same_*.bluebook (2 variants) - Equivalent but reordered

**Model Checking:**
- spec/fixtures/model_check/lifecycle_findings.bluebook
- spec/fixtures/model_check/policy_findings.bluebook
- spec/fixtures/model_check/saga_findings.bluebook

### Testing Opportunities

**High Priority (Domain Examples - Real Data):**
1. ✅ Pizzas - DONE (comprehensive 8-category testing)
2. ⏳ Banking - IN PROGRESS (needs full 8-category testing)
3. ❌ Compliance - NOT STARTED (empty stub, high priority for sagas)

**Medium Priority (Framework Bluebooks - Meta-Level):**
- Identity/Governance - Reusable auth framework
- Deploy - Infrastructure validation
- ConsoleSettings - Config DSL

**Medium-Low Priority (Test Fixtures - Edge Cases):**
- Payments/Settlement - Saga coordination
- Till - Complex state machines
- Reflex - Projection chains
- Evolution/Era - Schema migration bugs

**Language Testing (Foundational - Catches All Bugs):**
- Bluebook, Aggregate, Entity, Behavior, Reaction, Projection, Shape, Syntax, Vocabulary
- Expression (predicate sublanguage) - CRITICAL for invariants
- Translation (era migrations)

### Bug Discovery Heuristics by File Type

1. **Domain Examples** - Real-world scenarios, multiple aggregates interacting
   - Find: Data corruption, state violations, missing validations
   - Where: Bluebook DSL application, dispatch pipeline

2. **Language Bluebooks** - Meta-level, used to parse everything
   - Find: Parser bugs, grammar gaps, edge cases in syntax
   - Where: Language deserialization, validation

3. **Test Fixtures** - Designed to break specific things
   - Find: Edge cases, evolution bugs, saga coordination issues
   - Where: Specific feature interactions

4. **Framework Bluebooks** - Reusable patterns
   - Find: Security gaps, identity/auth bugs, config validation
   - Where: Cross-cutting concerns

### Next QA Testing Plan

Phase 1 (Current):
- ✅ Pizzas: All 8 categories tested
- ⏳ Banking: Running comprehensive 8-category tests now
- 🎯 Goal: 200 bugs (currently at 6: 4 fixed + 2 reported)

Phase 2:
- Test all test fixtures (payments, settlement, till, reflex)
- Test language bluebooks for meta-level bugs
- Look for query pipeline bugs (#11, #12 remediation)

Phase 3:
- Test framework bluebooks (identity, governance, deploy)
- Test evolution/era fixtures (schema migration)
- Test model-checking fixtures

Phase 4:
- Implement full QA bluebook domain to track bugs, fixes, reports
- Automate adversarial testing pipeline
- Generate coverage metrics
