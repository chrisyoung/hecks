# PRD 09 — Admit the ungoverned Resolver operators into the expression ledger

**Status:** Not started. This is a rewrite of the original draft — see "Correction, for the record" at the bottom. The self-hosting mechanism ADR 0030's Slice 1 set out to prove already exists and already works for 18 operators. This PRD closes a real, currently-live gap in it instead.

## The problem

`lib/hecksagain/grammar/expression.bluebook` declares `Expression::Operator` — a real, self-hosted, admitted-through-a-lifecycle ledger of every operator the expression grammar recognizes (`propose → render per target → admit`), replayed from `lib/hecksagain/grammar/expression_operators.json` by `spec/operator_conformance_spec.rb`. Eighteen operators are admitted this way today (`||`, `&&`, `!`, `.include?`, six comparisons, `+`, `.modulo`, three sign-tests, `.empty?`, `.to_s`, `.size`), and both Ruby's `projection.json` (`bin/expression_projection`) and Rust's generated `OperatorCategory` enum (`bin/project_kernel_capabilities`) are correctly derived from that one ledger. The mechanism works.

Twelve operator symbols do not go through it. `Bluebook::Expression::Resolver` (and its `block_predicates.rb` sibling) recognizes `.match?(...)`, `.present?`, `.blank?`, `.split("...")`, `.first`, `.last`, `.start_with?("...")`, `.end_with?("...")`, `.all? { }`, `.any? { }`, `.none? { }`, and `.find { }` — nine distinct node types, each added in a separate pass, each commented "vendored addition, not (yet) upstream hecksagain." None of the twelve was ever proposed through `expression.bluebook`. The ledger's own header states exactly what that means: *"an operator absent here is not a slow operator, it is not an operator."*

Concretely, today:
- `rust/src/kernel/expr.rs`'s `Expr` enum, the generated `OperatorCategory`, and every `expression_operators/*.rs` file are silent on all twelve — grepped, confirmed zero hits anywhere in `rust/`.
- `bin/rust_kernel_coverage` cannot catch this: it checks every category `Grammar.admitted_operators` lists, and these aren't on that list at all.
- `spec/operator_conformance_spec.rb` only holds the `comparison` category equal to `Evaluator::COMPARISONS`/`Vocabulary::Comparison` — nothing cross-checks the *inner*-grammar suffix/call-pattern set `Resolver#parse` actually recognizes against what the ledger admits, so this spec is green today despite the gap.
- Any real predicate using one of these twelve (and several already exist in the corpus — `.match?` on format-validation rules, `.split`/`.all?` on the `Phrase` value object, `.start_with?`/`.end_with?` on `Params`) evaluates correctly in Ruby and has no defined behaviour in Rust at all.

## Approach

1. **Inventory is exact, not estimated** — 12 symbols / 9 node types, confirmed by reading `resolver.rb` and `resolver/block_predicates.rb` directly: `MatchesRegex`, `Presence` (present?/blank?), `Split`, `First`, `Last`, `StartsWith`, `EndsWith`, `BlockPredicate` (all?/any?/none?), `Find`.
2. **Propose, render, and admit each through the existing `Expression::Operator` aggregate** — `grammar: "inner"`, `position` continuing the existing inner-grammar dense order, category named to fit Rust's existing convention where a real match exists, a new category where it doesn't (don't force `.match?` into `sized` just to avoid adding a category).
3. **Nine of the twelve fit the four existing strategies** (`suffix_match`: present?/blank?/first/last; `call_pattern_match`: match?/split/start_with?/end_with?). **Three don't** — `all?`/`any?`/`none?`/`find` (four symbols) open a `{ |x| PREDICATE }` block, which none of `top_level_split`/`prefix_match`/`suffix_match`/`call_pattern_match` describes. Don't force-fit them: propose a fifth `Strategy` value through the same `Operator` aggregate's own lifecycle, the way this ledger is meant to grow — or, if that turns out to need more than a new enum value (a block-opening operator's renderings may not fit the flat symbol/form pair the others use), scope it out explicitly as its own follow-up rather than mis-tagging four real operators to keep the count convenient.
4. **Regenerate and extend the conformance spec, not just the projection.** Run `bin/expression_projection`, confirm `spec/operator_conformance_spec.rb` still passes, then extend that spec itself: it needs a check holding the full admitted inner-grammar symbol set equal to what `Resolver` actually recognizes, the same shape its existing `comparison`-only check already has. That probably means extracting a named constant (e.g. `Resolver::ADMITTED_SUFFIXES`) out of the regex cascade `Resolver#parse` currently is — today there's no single table to hold the ledger equal to, which is exactly how this gap went unnoticed.
5. **Regenerate Rust's side** (`bin/project_kernel_capabilities`), then hand-write the `rust/src/kernel/expression_operators/<name>.rs` files `bin/rust_kernel_coverage` will now expect.
6. **Hand-edit `expr.rs`'s `Expr` enum, `category_of`, and `dispatch_operator`** to add the new variants and route them. `Expr` is explicitly hand-written today (its own header says so) — this is expected work, not evidence of a gap in the mechanism itself. The exhaustive match with no wildcard arm is exactly what turns "forgot one" into a compile error.
7. **Reuse existing corpus predicates as the test fixtures**, don't write synthetic new ones where real ones exist — the `Phrase`/`Params` value objects already exercise most of these operators live.

## Acceptance criteria

- [ ] All in-scope operator symbols (12, or fewer if step 3's block-predicate question is deliberately deferred) are proposed, rendered per target, and admitted in `expression_operators.json`, replaying with zero refusals.
- [ ] `spec/operator_conformance_spec.rb` extended to hold the full inner-grammar admitted symbol set equal to what `Resolver` actually recognizes — closing the exact blind spot that let this gap go unnoticed, not just adding rows to the ledger.
- [ ] `bin/rust_kernel_coverage` reports every newly-admitted category's Rust file present.
- [ ] `rust/src/kernel/expr.rs` interprets every newly-admitted node type with real hand-written logic, matching Ruby's `Resolver` exactly against the existing corpus fixtures that already exercise them (`Phrase`, `Params`, and any others found during step 7).
- [ ] Existing Ruby-side corpus/fuzzer/behaviors suites remain green — this PRD adds ledger entries and Rust code; it does not change Ruby's own `Resolver`/`Evaluator` behaviour.
- [ ] `bin/expression_projection --stdout` diffed against the checked-in `projection.json` is empty.

## Non-goals

- **Generating the `Expr` enum itself from the ledger.** `Expr` stays hand-written, as it is today. This PRD closes the admission/coverage gap in existing machinery; it does not build the further "generate `Expr` too" ambition ADR 0030 describes separately — that remains open, genuinely harder, work.
- **`Binding`, `Reaction`, or anything from ADR 0030's later slices.**
- **Retiring or renaming any already-admitted operator.**
- **Settling block-predicate strategy design beyond "propose one, if it's a clean fit."** If `all?`/`any?`/`none?`/`find` need more than a new `Strategy` value, that's a follow-up, not a blocker for the other eight symbols.

## Correction, for the record

The original version of this PRD (written before this inventory pass) proposed building `expression.bluebook`, an admission ledger, a projection generator, and generated Rust output from scratch — the ADR 0030 Slice 1 ambition, taken literally. All of that already exists and already works: `lib/hecksagain/grammar/expression.bluebook` (the `Operator`/`Normalisation` aggregates), `lib/hecksagain/grammar/expression_operators.json` (the ledger, replayed by `spec/operator_conformance_spec.rb`), `bin/expression_projection` (writes `projection.json`), and `bin/project_kernel_capabilities` (writes Rust's generated `OperatorCategory`/`AttributeShape` enums) — correct and working for 18 operators across 7 categories. In that sense, ADR 0030's Slice 1 question ("can one definition generate equivalent Ruby and Rust representations without handwritten duplication?") is already answered *yes*, by code that predates this ADR. What's actually open is narrower and more concrete: twelve operators grew outside that mechanism and need to be brought inside it — which is what this PRD now does.
