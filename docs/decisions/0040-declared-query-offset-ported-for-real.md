# Phase 10's first shipped capability — a declared AGGREGATE query's `offset`, ported for real

**Status:** Shipped, both generators, verified against a real corpus fixture that was previously a documented, tolerated gap. This closes one item of Phase 10's own "long-tail feature-completeness backlog" — the backlog itself stays open; see "What Phase 10 still leaves open," below.

## What shipped

A declared `query "X" do ... end` block's own `offset N` now generates for real, for the same subset `order_by`/`limit` already cover (one or more field-comparator conditions, ANDed, against a single aggregate's own attributes). Before this round, ANY declared `offset` — literal or a caller-bound Symbol arg, valid or not — made `rust/project/queries.rb#query_skip_reason` refuse the WHOLE query, unconditionally, the same way `cursor`/`consistency`/`authorization`/`null_semantics` still do.

Ground truth: `Runtime::QueryInterpreter#interpret` (`lib/hecks/runtime/query_interpreter.rb`) already had real `offset` support (a prior round in this same session fixed a bug where `declared.offset` was never read at all — see that file's own "OFFSET FIRST, THEN LIMIT" comments) — this round is purely the Rust side catching up to Ruby's own already-correct behavior, not new Ruby semantics.

**Kernel** (`rust/src/kernel/`):
- `query_ordering.rs` — `pub type Offset = Limit` (identical Literal/Arg wire shape, identical resolution rule — one type, two names, not a duplicate enum). `apply()` gained an `offset: Option<&Offset>` parameter, applied via `Vec::drain` AFTER the declared order and BEFORE the limit truncation — matching Ruby's own `skipped = ordered.drop(...)` then `capped = skipped.first(...)` sequence exactly (SQL's own `LIMIT n OFFSET m` order, not the reverse).
- `named_query.rs` — `QueryDef` gained `pub offset: Option<query_ordering::Offset>`, threaded into `run_cross_domain`'s own `query_ordering::apply` call.
- `read_model.rs` — its own `apply_filtered_head_options` call site now passes `offset: None` explicitly (a read model still has no `offset` field at all; `read_models.rb`'s own eligibility gate is unchanged — this is a real, currently open, separate item on Phase 10's own backlog, not silently closed as a side effect of this round).

**Both generators** (`rust/project/queries.rb` and `rust/codegen/src/queries.rs`, kept in parity per ADR 0010):
- `offset` removed from the combined `extras` refusal list.
- `declared_offset_skip_reason`/`emit_query_offset` added, mirroring `declared_limit_skip_reason`/`emit_query_limit` exactly (identical wire shape) — `emit_query_offset` reuses `emit_query_limit`'s own computation and swaps only the spelled Rust type name (`Limit::` → `Offset::`) so a generated `offset:` field doesn't read as a copy-paste bug to a human.
- `emit_query_def`/`QueryDef` (both generators) and the exemplar placeholder (`rust/src/exemplar/queries.rs`) all gained the new field.

`spec/codegen_parity_spec.rb --tag io`: 8/8 — both generators still produce byte-identical whole-file output on every real corpus member, offset included.

## The real, previously-catalogued gap this closes

`spec/corpus/rust_conformance/named_queries_order_limit.json` — already a real, existing fixture — has always exercised `Banking::ATMCard.ByFee` (`where(status: "active"); order_by :daily_fee; limit 3; offset 1` — the real corpus declaration in `examples/banking/bluebook/payment_cards.bluebook`, comment: "the second-cheapest three, skipping the very cheapest"). `spec/support/rust_conformance_helpers.rb`'s own `KNOWN_REFUSAL_GAP_VERBS` tolerated this ONE verb's refusal-vs-real-answer mismatch by name — a documented, narrow, known gap, not a silent one.

**RED, confirmed directly before any fix**: `bin/rust_conformance examples/banking spec/corpus/rust_conformance/named_queries_order_limit.json native` — exactly one mismatch, Rust refusing `Banking::ATMCard.ByFee` ("is not generated for this domain") where Ruby returns a real 3-row answer.

**GREEN, confirmed directly after**: same command, same fixture, against `examples/banking` regenerated with the fix — `matches.` `KNOWN_REFUSAL_GAP_VERBS` no longer needs to name this verb at all; removed.

## Regenerating banking (and why compliance/pizzas/meta/governance/identity/roster came with it)

`QueryDef` is one shared struct compiled into every domain unconditionally (`rust/src/generated/mod.rs` declares `pub mod <domain>;` for all of them with no `#[cfg(feature = ...)]` gate — only the `active` re-export is feature-scoped), so adding a field to it is a breaking change for every domain that has ANY declared query, not an additive one that could coexist with stale committed output. `bin/project_rust` was re-run for real against every in-repo domain with at least one `QueryDef` row (`banking`, `compliance`, `pizzas`; `meta`, the self-hosted language, regenerates automatically as a side effect of any run) — `roster` and `embryonaut` were also re-run/checked but have zero `QueryDef` rows in either's own tree, so neither's `.rs` content actually changed from this round (confirmed: `roster`'s regen touched only its own `ir.json`/`metadata.rs`/`roster.rs`, no `registry.rs`/`merged.rs` diff). `governance`/`identity` (shared framework chapters both `banking` and `pizzas` pull in via `uses_framework`) came along automatically as part of those domains' own regen — genuinely regenerated from real source both times, not hand-patched.

`embryonaut` itself lives in a separate repo (`embryonaut_bluebooks`, outside this checkout — the known dogfood coupling) and was deliberately NOT regenerated here: its own `registry.rs`/`merged.rs` declare zero `QueryDef` rows today, so the struct change doesn't break its build, and there is no `offset`-bearing query in it to prove anything against. Left untouched, matching the same "don't touch what you can't verify" discipline ADR 0037/0039 already established.

**Honest side effect, not scope creep**: because `banking`/`compliance`/`pizzas` had to be regenerated anyway (the struct change forces it), this round's regen ALSO picked up every already-landed-but-not-yet-regenerated generator fix from earlier in this same session (Phase 3's `none_in_state`, Phase 4's `gt`/`gte`/`lt`/`lte`-against-a-literal, wherever those touch `queries.rb`'s own output for these three domains) — this is unavoidable given the struct change, not a deliberate widening of this round's own scope. `spec/rust_conformance_spec.rb --tag io` (20/20) and the full suite (2232/0 failures) both confirm nothing broke; `spec/codegen_parity_spec.rb --tag io` (8/8) confirms the two generators are still in lockstep.

## What Phase 10 still leaves open

Read model `offset` (`read_models.rb`'s own eligibility gate — deliberately unchanged this round). The rest of the plan's own Phase 10 list, untouched: query/read-model `cursor`/`consistency`/`authorization`/`null_semantics`/`group_by`/`count`/`median`; mutation-op gaps (`sets` ops beyond append/set/increment/decrement/delegate; literal-to-target and cross-aggregate "door"-argument type-bridging limits; `list_of` with `admits:`/`pattern:`). ADR 0039's own finding that banking's committed artifact wouldn't pass the deploy-time parity gate is now PARTIALLY addressed (the offset-shaped mismatches it names are gone; the `corrects`-construct gap and the missing-argument-wording gap it also names are untouched, still open, still separately tracked) — banking's own artifact should be re-checked against the parity gate once those are closed too, not assumed clean from this round alone.

## Verification

- `cargo test --no-default-features --features banking` (rust/): 49 passed, 0 failed (kernel unit tests, `from_json_round_trip` integration tests).
- `cargo build --no-default-features --features {roster,compliance,pizzas,banking}`: all four clean.
- `bin/rust_conformance examples/banking spec/corpus/rust_conformance/named_queries_order_limit.json native`: RED before the fix (one mismatch, `Banking::ATMCard.ByFee`), GREEN after (`matches.`) — red-before/green-after against a real corpus fixture, not a synthetic one.
- `bundle exec rspec spec/rust_conformance_spec.rb --tag io`: 20/20.
- `bundle exec rspec spec/codegen_parity_spec.rb --tag io`: 8/8, byte-identical whole-file output on every real corpus member.
- `bundle exec rspec` (full suite): 2232 examples, 0 failures.
- `bundle exec rubocop -c .rubocop.yml` (the project's own real invocation, no file args): 645 files, no offenses.
