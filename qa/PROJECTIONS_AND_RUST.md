# Projections & Rust Runtime

**Last Updated:** 2026-08-11  
**Status:** ACTIVE - Rust projections are deployed to production

---

## Overview

hecksagain can compile bluebook domains to **multiple target languages**. The Ruby runtime is the primary/only execution environment for tests, but domains also compile to **Rust** for:

- Production deployment (AWS Lambda)
- Performance-critical paths
- Polyglot systems
- Web UI hosting (in-process with domain)

**Current Status:** Pizzas domain is **LIVE on AWS** at `https://mvvad4quxumohg2jw5qwdyzoke0gnaqd.lambda-url.us-east-1.on.aws/`

---

## What is a Projection?

A projection is an **independent translation** of a bluebook domain to another language that:
1. Generates code from the same IR (intermediate representation)
2. Implements the same semantics (commands, queries, invariants, events)
3. Can dispatch independently or coordinate with other projections
4. Passes its own differential tests against the Ruby runtime

**Projections so far:**
- ✅ Rust - Full implementation, used in production
- (Others planned: Go, Node, Python)

---

## Rust Projection Architecture

### Directory Structure

```
rust/
├── Cargo.toml                  # Rust project manifest
├── src/
│   ├── lib.rs                  # Main library
│   ├── main.rs                 # CLI tool
│   ├── generated/
│   │   ├── mod.rs              # Re-exports active domain
│   │   ├── pizzas/             # Generated Pizzas domain
│   │   ├── banking/            # Generated Banking domain
│   │   └── ...
│   ├── exemplar/               # Reference implementations
│   │   ├── commands.rs         # Example command dispatch
│   │   ├── mutations.rs        # Mutation logic
│   │   ├── reactions.rs        # Policy/saga reactions
│   │   └── ...
│   ├── kernel/                 # Core runtime
│   │   ├── pattern.rs          # Pattern matching
│   │   ├── evaluate.rs         # Expression evaluation
│   │   └── ...
│   └── generated_domains/      # Domain-specific code
├── host/                       # Lambda/web hosting
│   ├── src/
│   │   ├── main.rs             # Lambda entry point
│   │   ├── dispatch.rs         # Command dispatch
│   │   ├── web.rs              # Web UI serving
│   │   ├── wasm_runner.rs      # WASM execution
│   │   ├── auth.rs             # Authentication
│   │   └── journal.rs          # Event journal
│   └── Cargo.toml
├── web/                        # Frontend code
│   └── (TypeScript/React)
└── project.rb                  # Ruby generator script
```

### How Projection Works

**Generation Flow:**

```
.bluebook file (Ruby)
    ↓
Ruby runtime parses → IR (JSON)
    ↓
Rust code generator (lib/hecksagain/projector/rust/)
    ↓
Generated Rust code (rust/src/generated/<domain>/)
    ↓
cargo build
    ↓
Binary or .wasm module
    ↓
Deploy to Lambda / embed in web app
```

**Key File:** `rust/project.rb` - The Ruby script that generates Rust code from IR

### Domain Projection Strategy

Each domain compiles independently with a Cargo feature:

```toml
[features]
default = ["embryonautfoundersapp"]
embryonautfoundersapp = []
pizzas = []
banking = []
```

Build specific domain:
```bash
cargo build --no-default-features --features pizzas
```

The `generated::active` module re-exports whichever domain was built:
```rust
// rust/src/generated/mod.rs
#[cfg(feature = "pizzas")]
pub use self::pizzas as active;

#[cfg(feature = "banking")]
pub use self::banking as active;
```

---

## Production: Pizzas on AWS Lambda

### Current Deployment

**Live URL:** `https://mvvad4quxumohg2jw5qwdyzoke0gnaqd.lambda-url.us-east-1.on.aws/`

**Stack:**
- AWS Lambda (Rust binary)
- Aurora Serverless v2 (PostgreSQL)
- CloudFormation (infrastructure as code)

**Features:**
- 100% Rust (no Ruby in production)
- Web UI served in-process (`rust/host/src/web.rs`)
- Domain dispatch on same Lambda
- HTTPS enabled

### Deployment Process

1. **Generate Rust code** from bluebook via `bin/project_rust`
2. **Build** with `cargo build --release --features pizzas`
3. **Package** for Lambda (Rust binary + static assets)
4. **Deploy** via `bin/project_deploy` (CloudFormation)
5. **Verify** via live HTTP tests

### Known Issues Fixed During Deployment

- Missing port in app's own hecksagon (fixed)
- CloudFormation stack naming (fixed)
- Aurora secret management (fixed)
- RDS security group teardown leak (fixed)

---

## Testing: Parity Between Ruby & Rust

The project uses **differential testing** to ensure Rust dispatch matches Ruby:

### Parity Test Harness

**File:** `spec/parser_parity_spec.rb` (28+ tests)

**What it tests:**
1. Rust parser builds IR byte-identical to Ruby's
2. Rust dispatch produces same results as Ruby
3. Events recorded identically
4. Refusal paths match

**Current Status (2026-08-11):**
- 28 parser parity tests failing
- Issue: JSON formatting (empty arrays with newlines)
- This is **active Stage 5 work**, not a regression

### Running Parity Tests

```bash
# Build Rust parser
cargo build -p hecks-parse

# Run parity suite
rspec spec/parser_parity_spec.rb

# Run corpus tests
rspec spec/corpus_spec.rb
```

---

## Ports & Cross-Domain Dispatch

Rust projections can call **ports** (external integrations):

### Example: PaymentGateway Port

In Pizzas bluebook:
```ruby
port "PaymentGateway" do
  operation "Receive" do
    # accepts: amount, customer_id
    # returns: transaction_id
  end
end
```

In Rust code:
```rust
PaymentGateway::Receive {
  amount: pizza.price,
  customer_id: order.customer_id,
}
```

**Deployment:** Ports are deployed as separate Lambda functions, invoked via HTTP

---

## Web UI in Rust

**File:** `rust/host/src/web.rs`

The same Lambda that dispatches commands **also serves the web UI**:

```rust
pub async fn serve_web() {
  // Serve static HTML/JS
  // Handle form POST → command dispatch
  // Return rendered result
}
```

**Frontend:** TypeScript/React in `rust/web/`

---

## Performance & Characteristics

### Rust vs Ruby Runtime

| Aspect | Ruby | Rust |
|--------|------|------|
| Dispatch | ~10-50ms | ~1-5ms |
| Memory | ~200MB base | ~50MB base |
| Startup | ~2s cold start | ~500ms cold start |
| Parity | Reference impl | Generated from IR |
| Testing | Full test suite | Differential parity |

### When to Use Each

**Use Ruby:**
- Development & testing
- Exploring domain logic
- One-off scripts
- Rapid iteration

**Use Rust:**
- Production deployment
- High-performance paths
- Lambda/serverless
- Resource-constrained environments

---

## Common Tasks

### Generate a New Domain in Rust

```bash
bin/project_rust <domain_name>
```

This:
1. Loads the bluebook
2. Generates `rust/src/generated/<domain>/`
3. Adds feature to Cargo.toml
4. Runs cargo test

### Build & Test Rust Code

```bash
cargo build                    # Debug build
cargo build --release         # Optimized
cargo test                     # Run tests
cargo build --features pizzas # Build specific domain
```

### Deploy to AWS

```bash
bin/project_deploy <env>      # staging or prod
```

### Check Parity

```bash
rspec spec/parser_parity_spec.rb[1:5]  # Single test
rspec spec/parser_parity_spec.rb        # All parity tests
```

---

## For QA Testing

### What to Test in Rust Projections

1. **Parser parity** - Does Rust parse .bluebook same as Ruby?
2. **Dispatch equivalence** - Same commands → same results?
3. **Event ordering** - Events recorded in same order?
4. **Web UI** - Forms render, dispatch works, results display?
5. **Lambda behavior** - Cold start, memory limits, timeouts?

### Adding Rust Tests to QA Suite

Update `qa/SYSTEM_ARCHITECTURE.md` with Rust-specific sections:
- Projection architecture
- Parity testing strategy
- Production deployment checklist

Update `qa/qa_adversarial_fixed.rb` to test Rust-specific concerns:
- Parser edge cases
- Lambda startup performance
- Cross-domain port calls

### Known Rust Issues

- **Parser JSON formatting** (Active Stage 5)
  - Empty arrays formatted with newlines
  - Causes 28 parity test failures
  - NOT a semantic bug, just formatting

---

## How to Keep This Document Updated

When:
- ✏️ A new domain is projected to Rust
- ✏️ Deployment changes (new Lambda, new database)
- ✏️ Parity tests change status
- ✏️ New ports are added
- ✏️ Production bugs are found

Then:
- Update the "Current Status" section
- Add to "Known Issues" if needed
- Note the date and commit

This is a **living document** - it should stay accurate as Rust projections evolve.
