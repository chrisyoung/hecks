# Rust reads and writes any era Ruby mints — the lineage runtime, not the lineage authority

**Status:** Proposed — plan below, not yet implemented. Extends [0011](0011-rust-compiles-types-interprets-dispatch.md) and [0018](0018-rehydrate-replay-lambda-host.md); narrows the gap both named as still-open.

## Context

Ruby's era/lineage subsystem — multi-era schema evolution with `rename`/`move`/`convert`/`drop`/`retype`/`compute`/`rekey`/`backfill` migration rules, a three-layer audit, and a SHA-256 approval digest gating any `compute`/`rekey` mint — is real, load-bearing, and has no Rust counterpart for the *authoring* half. `lib/hecksagain/translation/` (611 LOC) and `lib/hecksagain/adapters/driven/postgres_era/` (2,315 LOC) mint eras, compile their migration rules into chained-CTE SQL (`lineage/head_compiler.rb`, ~500 LOC of hand-generated SQL text), and gate `compute`/`rekey` mints on a matching, unstale approval (`lineage_manager/minter.rb`). `docs/decisions/0011:26` and `0018:26` both flagged "Rust has no era concept at all" as an open gap.

That flag is now half stale. `rust/host/src/journal.rs` (876 lines) has grown a second path since 0018 was written — its own header says so directly: *"the generic lineage read/write functions further down this file... are the part of this crate that does"* have an era concept. That path (`LineageConfig`, `current_era()`, `append_lineage_mutation()`, `read_lineage_head_all`/`read_lineage_head_by_id`) reads and writes against the exact era-partitioned Postgres schema Ruby's `PostgresEra`/`Lineage` provisions — including the precompiled `<storage>_head` matview `head_compiler.rb` builds at mint time. Rust never re-derives that SQL; it selects from a view Ruby already compiled. A real integration test (`mint_stale_era.rb`, shelled out to real Ruby) already proves Postgres's RLS fence — not Rust's own logic — is what refuses a write against a superseded era. Today this generic path has exactly one consumer: `Member`, wired by hand in `auth.rs`.

**This narrows the real gap to a specific question, not "port ~3,900 LOC of Ruby to Rust":** should Rust ever independently *mint* an era — provision, compile migration SQL, run the audit, gate on an approval digest — or should it only ever *read and write against* eras that Ruby has already minted? Two of this project's own standing decisions bear directly on that fork:

- **[0010](0010-ruby-is-the-reference-implementation.md)** — Ruby is the reference implementation. Schema evolution is exactly the kind of low-frequency, human-in-the-loop, operator-run action (`bin/translation_audit --approve`, then a boot-time mint) that this pattern already exists for.
- **[0011](0011-rust-compiles-types-interprets-dispatch.md)** — "compile per-command-shape into Rust source" was tried and explicitly did *not* converge; "needed a new hand-written case in the generator... the same failure mode, one level down." `head_compiler.rb`'s chained-CTE SQL compilation is exactly that shape of problem — order-dependent, comment-documented as unsound if flattened, and it changes only when a migration rule is authored, which already happens in Ruby.

Both point the same direction: minting stays Ruby's job, permanently, the same way parsing and dispatch-shape compilation already split between the two runtimes. What Rust needs is full **operational** parity — correct reads and writes against any era, for every lineage-capable aggregate, not just `Member` — not **authoring** parity.

## Decision

Scope this to the narrower question: **generalize what already works for `Member` to every aggregate `rust/build/src/lineage_pass.rs` marks `lineage_capable?`, and verify it holds at every era boundary.** Concretely:

1. **Generalize the read/write path beyond `Member`.** `auth.rs`'s lineage wiring is hand-written for one aggregate. Extend `rust/build/src/lineage_pass.rs` to emit a generated per-aggregate lineage repository (config: table/view names, id-field mapping) for every aggregate the Ruby side exports via `Projector::Exporter.lineage`, the same way flat-journal repositories are already generated per domain (`rust/project/{naming,domain_generator,registry}.rb` pattern per [0016](0016-rust-generates-role-checking.md's sibling ADRs)). This is wiring, not migration logic — the risk surface is "wrong table/column name," not "wrong migration semantics," because Rust still only ever reads the view Ruby compiled.
2. **An existence-check CI backstop**, in the same spirit as `bin/rust_kernel_coverage`'s no-comment-tag file-existence check: for every aggregate the live Ruby grammar marks `lineage_capable?`, does a generated Rust repository module exist for it? A missing one fails loudly at build/CI time, not silently at first production read.
3. **Extend the stale-write test to a concurrent-with-mint case.** `mint_stale_era.rb` today proves a write against an *already-superseded* era is refused. It does not yet prove correctness for a write racing `advance_era!`'s RLS-flip itself. Add that case.
4. **A live-Postgres differential-parity test**, structured like `spec/rust_conformance_spec.rb`'s pinned-fixture pattern but driven by real eras: use Ruby to mint a short chain of eras against the existing `spec/fixtures/eras/*.bluebook` pairs (11 shape-drift kinds already fixture'd) — including at least one `compute`/`rekey` era, which needs a real approval — then read and write the same data through both Ruby and Rust and hold every result equal. `spec/corpus/fixtures/lineage_v1*.json` and `lineage_check.json` already script cross-era command sequences usable as the seed data.
5. **Explicitly not ported to Rust**: provisioning (`lineage/provisioning.rb`), the mint transaction (`lineage/mint_transaction.rb`), the three-layer audit (`translation/audit*.rb`), the approval-digest store/gate (`translation/audit/approval_digest.rb`, `lineage_manager/minter.rb`), the scaffold/differ (`translation/scaffold*.rb`), and `head_compiler.rb`'s SQL generation. These stay Ruby-only, by decision, not by remaining gap — see Consequences.

## Consequences

- **Rust stays dependent on Ruby to mint.** A pure-Rust deployment with no Ruby anywhere (the WASM/browser target, `rust/web/`) cannot participate in lineage-capable domains at all — true today, unchanged by this plan. Flag this as an explicit, permanent limitation of those targets, not a bug to later close.
- **Parity risk is structurally lower than a full port would carry**, and that's the point of this scoping: because Rust reads the *same* compiled `_head` view Ruby produces rather than re-deriving migration SQL, a correctness bug in `head_compiler.rb`'s chained-CTE logic can't diverge between runtimes — there's only one implementation of it. The remaining risk is entirely in the generic wiring (step 1) and the boundary-timing case (step 3).
- **If a real production need for Rust-only schema evolution ever emerges**, that's scope this plan deliberately declines — a distinct, much larger follow-on decision needing its own ADR, not something to grow into silently here. Should that day come, `0022`'s precedent (generate Rust's operator table from Ruby's self-hosted grammar rather than hand-port it) is the shape to imitate for `head_compiler.rb`, not a from-scratch Rust SQL compiler.
- **`0018`'s status line should be corrected once this ships**, the same way `0022`'s was corrected in this same pass — it still reads "Rust has no era/lineage concept at all," which is no longer accurate even before this plan, let alone after.

## Rejected alternatives

- **Full port — Rust independently mints, migrates, and audits (scope A).** Rejected for now. Contradicts [0010](0010-ruby-is-the-reference-implementation.md)'s standing decision and repeats the specific failure mode [0011](0011-rust-compiles-types-interprets-dispatch.md) already documented at smaller scale (per-command codegen not converging). Revisit only against a documented production need, not as a default ambition.
- **Do nothing — leave `Member` the only lineage-capable aggregate Rust handles.** Rejected — the standing requirement is that Rust and Ruby run identically in production, and today only one aggregate out of however many are `lineage_capable?` is covered; every other lineage-capable aggregate is an unverified gap, not a proven one.

## Sequenced work plan

Same discipline as [0025](0025-the-dsl-names-one-idea-one-way-and-a-word-earns-its-place-by-being-used.md)'s: the fixture harness lands first so every later commit has a safety net, not last as a victory lap.

| # | commit | depends on | notes |
|---|---|---|---|
| 0 | stand up the differential-parity harness (item 4) against `Member` only, using the existing `spec/fixtures/eras/*.bluebook` + `lineage_v1*.json` fixtures | — | proves the harness works on the one aggregate already wired before trusting it to judge new ones |
| 1 | generalize `lineage_pass.rs` to emit a per-aggregate repository (item 1); migrate `auth.rs`'s hand-written `Member` wiring onto the generated form | 0 | `Member` must keep passing the harness from 0 throughout — regression, not just new coverage |
| 2 | existence-check CI backstop (item 2) | 1 | mirrors `bin/rust_kernel_coverage`'s existence-not-comment-tag design |
| 3 | extend harness to every other `lineage_capable?` aggregate in the real corpus domains (Banking, etc.) | 1, 2 | this is where the actual gap closes — each new aggregate is a small, bounded commit |
| 4 | concurrent-with-mint write race test (item 3) | 1 | extends `mint_stale_era.rb`'s pattern rather than replacing it |
| 5 | include a `compute`/`rekey` era (with a real approval) in the harness, not just the five portable rule kinds | 0, 3 | the only rule kinds with no in-process Ruby reference implementation either — highest-value case to prove, done last because it needs the harness mature first |
| 6 | correct `0018`'s stale status line; record what shipped, following `0022`'s corrected format | all | keeps the docs from lying the way `0022`'s did for ten days |

Sizing: the generalization work (steps 1–3) is wiring around an existing, working single-aggregate case — small relative to the ~3,900 LOC the full Ruby subsystem represents, because that LOC count includes provisioning/audit/scaffold/SQL-compilation this plan deliberately does not port. The harness (steps 0, 4, 5) is the larger share of the real effort, proportionate to the user's explicit parity requirement.
