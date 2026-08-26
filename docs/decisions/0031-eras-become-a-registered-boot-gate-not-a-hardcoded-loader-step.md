# Eras become a registered boot gate, not a hardcoded loader step

**Status:** Proposed — not yet reviewed or implemented.

## Context

An **era** is a schema-evolution/lineage concept: an immutable, numbered snapshot of a bluebook's storage shape, plus a translation edge (rename/move/convert/drop/retype/compute/rekey/backfill) describing how data from the previous shape maps onto the new one. It exists so a running Postgres-backed domain survives a schema change without a conventional migration tool — every past era's data is read through a compiled view chain that translates it on the fly.

Era logic is scoped to one adapter already — `Adapters::PostgresEra` (`lib/hecks/adapters/driven/postgres_era.rb` and its `postgres_era/`, `lineage/` subdirectories) carries all of it; the plain `Adapters::Postgres` has none (`docs/implemented/postgres-era-adapter-split-plan.md`). But the *code that decides whether to run era-checking at all* is not scoped the same way:

- `Runtime::Loader.boot`/`boot_files` (`lib/hecks/runtime/loader.rb:49,98`) call `Runtime::EraCheck.check!(registry, directory)` **unconditionally**, as a fixed step between loading and `registry.verify!`, on every domain boot — whether or not that domain's adapter has any notion of eras.
- Inside `EraCheck`, the actual "does this adapter care about eras" question is a clean capability check — `adapter_class.respond_to?(:lineage_capable?) && adapter_class.lineage_capable?` (`lib/hecks/runtime/era_check.rb:128-133`) — but the caller of that check is not itself behind anything registrable. It's a name, hardwired into the loader.
- `Runtime::EraGuard`/`Runtime::EraTamper` reach directly into `Bluebook::MetaValidator` and several DSL builder internals (`value_object_builder.rb`, `attribute_collector.rb`, `translation_builder.rb`, `identity_declaration.rb`) to shadow-parse historical bluebook text under old grammar defaults — machinery a non-lineage adapter's boot has no business depending on.
- The dependency also runs backward: `PostgresEra::LineageManager::CoverageCheck` (mint-time coverage checking) calls back *up* into `Runtime::EraGuard`. `era_tamper.rb:13-19`'s own comment flags this as the exact shape that has caused trouble in this codebase before — a runtime module and an adapter calling into each other.
- `Runtime::Projector::Exporter` (`lib/hecks/projector/exporter.rb:36-37`) also calls `Runtime::EraCheck.adapter_for`/`.lineage_capable?` directly, so era-awareness leaks into IR export too.
- Rust independently re-implements the same mint/audit sequence at its own boot gate (`rust/host/src/main.rs`, `mint.rs`, `storage_shape.rs` — ADR [0030](0030-rust-mints-its-own-eras-at-boot.md)), so any change to how Ruby decides "run era-checking or don't" needs an answer on the Rust side too, not just Ruby's.

This codebase already has one deliberate, named extension point: the Projector registry (`lib/hecks/projector.rb`, ADR [0027](../implemented/decisions/0027-canonical-ir-and-the-projector-framework-are-the-seam.md)) — `register(name, projector)`/`call(name, ...)`, with a target declaring `projects_as :key, requires: SomeCapability`. It is the wrong shape for eras: it is explicitly IR-in/artifact-out, no bindings, no live-state mutation — era-checking gates boot and era-minting writes to the database, both disqualified by the Projector module's own taxonomy (`lib/hecks/projector.rb:20-43`).

No prior ADR discusses extracting eras or building a generic boot-time extension mechanism. This is new ground, not a reversal of anything decided.

## Decision

Introduce a small **boot-gate registry** that `Runtime::Loader.boot` walks generically, modeled on the Projector registry's own `register`/`call` idiom rather than invented from scratch:

- A gate is anything responding to `call(registry:, directory:)`, registered under a name — e.g. `Runtime::BootGates.register(:era_check, Runtime::EraCheck)`.
- `Loader.boot`/`boot_files` stop calling `EraCheck.check!` by name. They call `Runtime::BootGates.run_all!(registry:, directory:)`, which walks whatever is registered, in registration order, and lets each gate refuse boot on its own terms (raising, exactly as `EraCheck.check!` does today — no weakening of the "refuse to boot" guarantee ADR 0030 depends on).
- **Registration becomes conditional on the bound adapter, not global.** At boot, before running gates, the loader asks the resolved adapter class the same question `EraCheck` already asks internally (`respond_to?(:lineage_capable?) && lineage_capable?`) and only registers `:era_check` when that's true. A domain wired to `Adapters::Memory` or plain `Adapters::Postgres` never registers the gate at all — not "runs the check and it no-ops," but structurally absent from that boot's call graph.
- `Runtime::EraCheck` itself is unchanged in what it does; what changes is who calls it and when it's known about.

This alone fixes the *caller*-side coupling (Loader knowing era-checking exists by name) but not the *content*-side coupling. Two follow-on moves close that:

1. **Invert the adapter↔runtime back-reference.** `PostgresEra::LineageManager::CoverageCheck` currently calls up into `Runtime::EraGuard`. Since `EraGuard`'s shadow-parsing machinery (`era_guard/shape_diff.rb`, the `MetaValidator`/DSL-builder hooks) exists *only* to support Postgres-era lineage, move it to live under the adapter's own namespace (e.g. `Adapters::Driven::PostgresEra::ShadowParse`), leaving `Runtime::` with no era-specific code that isn't the thin, generic gate contract. `Runtime::EraTamper` moves the same way, for the same reason its own comment already names.
2. **Mirror the conditional on the Rust side.** Rust has no runtime plugin system and shouldn't grow one solely for this — its boot gate (`main.rs`) instead reads a flag already implied by `ir.json`'s adapter binding (whether the shipped domain declares a lineage-capable persistence adapter) and skips the mint/audit sequence entirely when it doesn't, rather than running a no-op check. This keeps Rust's side a static, compiled-in branch (consistent with [0011](../implemented/decisions/0011-rust-compiles-types-interprets-dispatch.md)'s "Rust compiles types, interprets dispatch"), not a second registry.

`lib/hecks/projector/exporter.rb`'s direct `EraCheck.adapter_for`/`.lineage_capable?` calls are unaffected by this ADR — that's export-time IR shaping, a different seam, not boot gating.

## Consequences

- A domain bound to a non-lineage adapter has zero era-related code in its boot call graph, structurally — not skipped by a runtime `if`, but never registered. Matches how the adapter/port system already treats optional capabilities (e.g. `query` falling back to `Ports::Query::InMemory` when unbound) rather than inventing a new idiom.
- Adding a future boot-time gate (for anything else that should refuse-to-boot under some condition) no longer means editing `Loader.boot` again — it means registering another named gate, the same way adding a projection means registering another projector.
- This does not reduce the total amount of era code or its inherent complexity — the mint/audit/translation machinery is unchanged. It relocates *who calls what*, so that a non-lineage domain's boot path, `Runtime::` itself, and the DSL/parsing internals are no longer coupled to a concern that only one adapter has.
- The "refuse to boot until a human authors and approves a translation edge" guarantee ([0030](0030-rust-mints-its-own-eras-at-boot.md)) must not become skippable by mis-wiring — the registry conditions on adapter capability the same way `EraCheck` does today, not on any configuration a domain author could accidentally omit. This needs a spec asserting that a domain bound to `PostgresEra` always ends up with the gate registered, mirroring `spec/projector_seam_spec.rb`'s "every projection file must be live in the registry" enforcement.
- Rust gets no new abstraction; its boot gate becomes conditional on statically-known information already in `ir.json`, not a second plugin system.
- This is additive and mechanical enough to land in stages: (1) the registry + conditional registration in `Loader`, independently testable and reversible; (2) the `EraGuard`/`EraTamper` namespace move into the adapter, a pure relocation; (3) the Rust-side conditional, last, since it depends on nothing from (1)/(2) but should confirm `ir.json` already carries what it needs.

## Rejected alternatives

- **Leave era-checking as an unconditional `Loader.boot` step.** Correct today only because every currently-shipped domain either uses `PostgresEra` or tolerates the no-op check silently — but it means the loader, `Runtime::` internals, and DSL builders all carry code that exists for one adapter's sake, and any future non-Postgres lineage-capable adapter (or a second storage backend that wants its own boot gate) has nowhere to plug in without editing `Loader` by hand.
- **Model era extraction on the Projector registry directly.** Rejected — wrong shape. Projector is deliberately IR-in/artifact-out with no bindings and no live-state mutation (`lib/hecks/projector.rb:20-43`); era-checking gates boot and era-minting writes to the database, both outside that contract.
- **A general-purpose middleware chain around `Runtime::Dispatcher`**, solving this and any future cross-cutting concern at once. Out of scope here — no second use case has actually asked for one yet, and `Dispatcher`'s interpreters are a different seam (command dispatch, not boot gating) than what eras need. Building a generic chain speculatively repeats the mistake ADR [0022](0022-self-host-the-expression-grammar.md) exists to warn against (a second general mechanism built before a second real need justifies it).
- **Give Rust its own boot-gate registry to mirror Ruby's.** Rejected — Rust has no domains that need more than one conditional gate today, and a registry there would be a runtime mechanism this crate has deliberately avoided elsewhere (compiled dispatch, not dynamic lookup — [0011](../implemented/decisions/0011-rust-compiles-types-interprets-dispatch.md)). A static conditional on `ir.json`'s adapter binding gets the same result without it.
