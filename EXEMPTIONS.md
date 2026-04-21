# Antibody exemptions

`bin/antibody-check` flags every added or modified file that isn't one
of the five Hecks source DSLs (`.bluebook`, `.hecksagon`, `.fixtures`,
`.behaviors`, `.world`). This file is the shared vocabulary of **why**
certain categories of non-DSL code legitimately exist today.

Every exemption is still per-commit — put `[antibody-exempt: <category>]`
(or `[antibody-exempt: <free-text reason>]`) in a commit message on the
branch. The category names below are the accepted shorthand; the
antibody treats them identically to any other reason string.

---

## runtime:ruby

Ruby is the bluebook interpreter. It stays indefinitely — Ruby is more
readable than Rust for expressing the business operations that make up
the runtime itself (dispatcher, event bus, command handling, saga
orchestration, etc.).

Over time the Ruby runtime becomes a thin wrapper that shells out to a
compiled Rust binary for the performance-critical work, preserving the
"readable surface" while hitting native speed underneath.

Paths: `lib/hecks/**`, `lib/hecks_*/**`, `spec/**`

## runtime:rust

Rust lives under `hecks_life/`. Destination: a standalone binary that
the Ruby runtime wraps for hot paths. Until the wrapper story is
stable, changes to parser / IR / dispatcher Rust are runtime work.

Paths: `hecks_life/**`

## ecosystem:python-ml

Summer's current `*.py` files wrap MLX + Modal. MLX and Modal stay
external — they're a world we call into, not code we absorb. But the
`.py` files in `hecks_conception/summer/` were still *authored* here,
and that's the gap: we should reach those ecosystems through a
`.hecksagon` adapter that dispatches to MLX/Modal's own APIs, not
through Python modules we maintain.

Arc: shrink `summer/**` toward zero authored Python. The adapter
lives in `.hecksagon`; ML training/serving commands live in
`.bluebook`; the hot path crosses a well-defined boundary into the
external Python runtime that MLX/Modal provide.

Paths: `hecks_conception/summer/**`

## bootstrap:ci

GitHub Actions workflow YAML. Stays until a `.hecksagon` adapter can
describe CI natively and a generator can emit the workflow files.

Paths: `.github/workflows/**`

## bootstrap:git-hooks

Shell + Ruby under `bin/` and `bin/git-hooks/`. Thin wrappers gluing
bluebook to git. Stays until `#!/usr/bin/env hecks-life run` shebang
is a stable entry point.

Paths: `bin/**`

## tool:audit

One-off hygiene tools (features_audit, etc.) written in Python or Ruby.
Each one is a transitional gap — when hecks-life can dispatch
audit-shaped commands against the codebase, these move to `.bluebook`
+ `.hecksagon`.

Paths: `tools/**`

---

## How to use this file

When the antibody flags a file you're touching, first ask: is there an
existing category that fits? If yes, reference it:

```
fix: patch the command bus so saga steps retry on transient errors

[antibody-exempt: runtime:ruby]
```

If it doesn't fit any category, either add a new one here (in the same
PR) or write a specific free-text reason:

```
feat: wire llms.txt generator

[antibody-exempt: generator scaffolding pending i20 ontology ingestion]
```

No permanent path-based allowlist. Each commit speaks for itself; this
file is just the running summary of what "the usual suspects" look like.
