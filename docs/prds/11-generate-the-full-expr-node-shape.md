# PRD 11 — Generate `Expr`'s full node shape from one source

**Status:** Not started. This is the "genuinely harder work" PRD 09's own Non-goals and ADR 0022 both explicitly deferred — the piece ADR 0030's Slice-2 reassessment names as the realistic next gate before `Reaction` (Slice 3) is warranted, not a third small-scale structural exercise like Binding's.

## The problem

PRD 09 and PRD 10 both closed real structural-duplication gaps using the same proven pattern — one generated source for *structure*, hand-written *meaning* on each side. But both were scoped narrowly: PRD 09 generates `OperatorCategory` (7 categories, later 11), not the `Expr` enum itself; PRD 10 generates `Source`/`ExecutableBinding` (2 variants), a shape ADR 0030 designed fresh. Neither touched the actual, original ADR 0022 complaint, which stands exactly as it did before either PRD: `rust/src/kernel/expr.rs`'s `Expr` enum (17 variants today) and Ruby's `Evaluator`/`Resolver` node structs (28 total across `evaluator.rb`, `resolver.rb`, `resolver/block_predicates.rb`) are two fully independent, hand-typed declarations of the same node shapes — not generated from anything, not checked equal to anything. A node added to one side and not the other compiles/runs fine on both, silently drifting, with nothing to catch it until a real predicate exercises the gap (exactly PRD 09's own discovery story, one level up).

This is the one piece both prior PRDs' honest self-assessment converged on: closing it is what actually retires ADR 0022's original diagnosis, rather than working around it at the edges.

## Approach

1. **One manifest, same pattern as `BindingShape`, applied to the full node set.** `Hecksagain::Bluebook::Expression::NodeShape` (or similar — name TBD) declares every `Expr`/`Evaluator`/`Resolver` node's field shape: `Or{left, right}`, `And{left, right}`, `Not{node}`, `Compare{op, left, right}`, `Include{haystack, needle}`, `IntegerLiteral{value}`, `FloatLiteral{value}`, `StringLiteral{value}`, `BoolLiteral{value}`, `NilLiteral{}`, `Addition{left, right}`, `SignTest{op, receiver}`, `Empty{receiver}`, `ToS{receiver}`, `Modulo{receiver, divisor}`, `Size{receiver}`, `Lookup{path}`, plus PRD 09's `MatchesRegex`/`Presence`/`Split`/`First`/`Last`/`StartsWith`/`EndsWith` — roughly 24 nodes with a settled shape today.
2. **`ArrayLiteral` needs a decision, not an assumption.** It's a real Ruby `Resolver` node with no Rust `Expr` equivalent at all today (Rust's `Value::List` is count-only — the same gap PRD 09's `string::split`/`accessor::{first,last}` already named and refused honestly). Generating its *structure* is easy; whether to generate it at all before `Value::List` can carry real elements is a real question — default to generating the structure (cheap, harmless) while leaving Rust's interpretation refusing, exactly the PRD 09 precedent, rather than blocking this PRD on the `Value::List` redesign.
3. **`BlockPredicate`/`Find` (`.all?`/`.any?`/`.none?`/`.find`) stay out of scope**, consistent with PRD 09's own deferral — they were never admitted through the operator ledger (no `Strategy` value describes a block-opening operator yet), so there's no settled canonical shape to generate *from*. Including them here would mean designing that shape as a side effect of a generator PRD, the same "don't decide design questions inside implementation" discipline PRD 09 already held itself to.
4. **Generate `Expr`'s Rust enum wholesale** from the manifest — replacing today's hand-typed 17-variant (soon 24) enum in `expr.rs` with a `mod.rs`/logic split, the same shape PRD 10 just proved for `binding/`. `category_of`/`dispatch_operator` — real routing logic, not structure — stay hand-written.
5. **Check Ruby's own node structs equal to the manifest**, not generate them — same call PRD 10 made for `BindingLowering`'s structs, same reasoning: Ruby's `Struct.new(...)` declarations are already the simplest possible spelling: a generator producing them would add a build step without reducing real duplication risk. A conformance spec (matching `binding_shape_spec.rb`'s own shape) holds `Evaluator`/`Resolver`'s real struct member lists equal to the manifest, both directions.
6. **Regenerate-then-diff as the acceptance bar**, matching every prior generator in this repo (`bin/expression_projection`, `bin/project_kernel_capabilities`, `bin/project_binding_shape`) — determinism and currency are non-negotiable, not aspirational.
7. **Do not touch interpretation logic.** `Evaluator#interpret`, `Resolver#interpret`, `expr.rs`'s `interpret`/`dispatch_operator`, and every `expression_operators/*.rs` file's actual logic stay exactly as they are. This PRD is structure-only, the same boundary PRD 09/10 both held.

## Acceptance criteria

- [ ] One manifest declares every in-scope node's field shape (≈24 nodes — see step 1/3 for what's excluded and why).
- [ ] `rust/src/kernel/expr.rs`'s `Expr` enum is generated from that manifest, structurally identical to today's hand-typed version for every node the manifest currently covers — a pure refactor from Rust's side, zero behaviour change.
- [ ] Ruby's `Evaluator`/`Resolver` node structs are checked equal to the manifest (member names, both directions) by a new conformance spec, the same shape `binding_shape_spec.rb` already uses.
- [ ] Regenerating produces an empty diff against the checked-in generated file.
- [ ] `cargo build`/`test`/`clippy` clean; existing Ruby corpus/fuzzer/behaviors suites and the existing `spec/operator_conformance_spec.rb`/`spec/expression_spec.rb` remain green, byte-for-byte unchanged in behaviour.
- [ ] ADR 0030's own stop-condition table (last run in ADR 0030's "Reassessment" section) is re-run after this PRD lands, with "did duplicated grammar disappear" now checkable against the *original* ADR 0022 complaint, not just what PRD 09/10 touched.

## Non-goals

- **Generating interpretation logic.** `interpret`/`dispatch_operator`/every `expression_operators/*.rs` function body stays hand-written, unchanged, per the "generate structure, handwrite meaning" boundary this whole proof sequence is built on.
- **`ArrayLiteral`'s real Rust representation** (i.e., extending `Value::List` to carry elements). Structure generates; interpretation keeps refusing, exactly PRD 09's own precedent for `.split`/`.first`/`.last`.
- **`BlockPredicate`/`Find` / `.all?`/`.any?`/`.none?`/`.find`.** Still unadmitted; still not this PRD's decision to make.
- **`Reaction`, `ReactionContext`, or anything from ADR 0030 Slice 3.** This PRD is what ADR 0030's own reassessment names as the prerequisite gate, not a step past it — Slice 3 starts only after this lands and the stop condition is re-run clean.
- **A self-hosted admission ledger for nodes**, matching `Operator`'s propose/render/admit lifecycle. Same reasoning `BindingShape`'s own header already gives: this is a closed, ADR-defined grammar, not an open-ended vocabulary — a plain manifest is the right-sized tool, not a ledger built for growth nobody is asking for.
