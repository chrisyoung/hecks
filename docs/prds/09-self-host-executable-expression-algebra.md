# PRD 09 — Self-host the executable expression algebra

**Status:** Not started. This is Slice 1 of ADR 0030's proof sequence and the concrete implementation of ADR 0022 — deliberately narrower than ADR 0030 itself. It proves one thing only: that Hecksagain can define a tiny executable semantic structure once, derive equivalent Ruby and Rust representations from it, and leave each runtime responsible for only a tiny irreducible interpretation kernel. Nothing else.

## The problem

`rust/src/kernel/expr.rs` is a hand-port of Ruby's `Bluebook::Expression::Evaluator`/`Resolver` — two independently authored implementations of the same small, closed grammar (ADR 0022). Each new expression operator has to be added by hand, twice, in agreement, with nothing but discipline keeping them that way.

## Approach

1. **One structural source of truth.** Declare the executable expression algebra in Hecksagain's own Bluebook idiom — a location that reads as kernel semantics, not ordinary author-facing grammar (`lib/hecksagain/language/kernel/expression.bluebook` if that split exists in the current tree, otherwise the closest equivalent — check before inventing a new namespace). It describes node *structure* only: shapes, arities, result types. No implementation code, no per-target (`ruby:`/`rust:`) strings — the moment a definition needs those, it has crossed into being an interpreter/template language, which this PRD must not do (ADR 0030's "generate/handwrite boundary").

2. **Derive the v1 node inventory mechanically, from the real code — not from this PRD.** Before writing the definition, inventory every expression shape actually accepted and executed today, reading `Evaluator`, `Resolver`, `rust/src/kernel/expr.rs`, and the expression-related grammar directly. No new operators, no removals. Expected, pending that inventory (ADR 0022/0030 already cite "six operators, reduced to two primitives plus a small boolean algebra"): `Literal`, `Reference`, `Equal`, `LessThan`, `And`, `Or`, `Not`. If the real code contains something not on this list, the code wins — classify it primitive vs. derived using step 3's rule rather than redesigning the list here.

3. **Derived operators normalize to primitives; they are never executable nodes.** `greater_than(a,b) = less_than(b,a)`; `not_equal(a,b) = not(equal(a,b))`; `less_than_or_equal(a,b) = or(less_than(a,b), equal(a,b))`; `greater_than_or_equal(a,b) = or(less_than(b,a), equal(a,b))`. These reductions are themselves declarative — generate one normalization/lowering stage from a single declared source, shared by both runtimes. Authoring syntax (`>`, `!=`, `<=`, `>=`) may keep working; the executable expression graph never contains those node kinds.

4. **`Reference` is structure; `resolve` is evaluator behaviour.** Keep that split — `Reference` is an AST node holding a path; `resolve(reference, context)` is an operation the handwritten evaluator performs, not a node type — unless inventory (step 2) shows the current code already collapses them, in which case match what exists.

5. **Generate checked-in files, not runtime-constructed models.** `lib/hecksagain/generated/kernel/expression.rb` and `rust/src/generated/expression.rs` (adjust paths to match whatever generated-artifact convention the repo already has — check for one before inventing paths), each containing the node types/codecs/visitors the existing evaluators need. Keep the existing `Evaluator`/`Resolver` call-site API compatible via a thin adapter rather than rewriting every caller in this PRD.

6. **Handwritten evaluators shrink to the irreducible set.** Once generation and normalization are in place, `Evaluator`/Rust `kernel/expr.rs` should each contain a case only for the primitives found in step 2 — no case for a derived operator, no second handwritten node-shape declaration anywhere.

7. **Generation is deterministic, checked in, and never required at boot.** A generator command (match the repo's existing `bin/` convention rather than inventing a new one) that produces identical output on every run, with a "generated, do not edit" header naming its source definition. Production boot must not depend on running it.

## Acceptance criteria

- [ ] One structural definition of the expression algebra exists; grepping the repo for expression node variants finds it as the only manually maintained declaration — no second handwritten enum/case list anywhere that must be kept in sync by hand.
- [ ] Ruby and Rust expression-node representations are both generated from that one definition.
- [ ] Derived operators (`greater_than`, `not_equal`, `<=`, `>=`, and whatever else step 2's inventory finds) normalize to primitive compositions through one generated/declared reduction; neither evaluator has a case for a derived operator.
- [ ] Each runtime hand-implements only the primitives step 2's inventory actually finds — confirm the list against the code before treating `Literal/Reference/Equal/LessThan/And/Or/Not` as final.
- [ ] Regenerating from the source definition produces an empty `git diff` against the checked-in generated files.
- [ ] Structural tests exist and pass: generation is deterministic; Ruby and Rust expose the same node variants; no derived-operator name reaches either evaluator; regenerate-then-diff is clean.
- [ ] Evaluator parity tests exist per primitive (literal; reference resolution; `equal` true/false; `less_than` true/false; `and`/`or` — including short-circuit if that's current behaviour — `not`), plus normalization-equivalence tests per derived form (e.g. `evaluate(a > b) == evaluate(b < a)`), not one test per runtime per derived operator.
- [ ] Existing corpus + fuzzer (ADR 0024 infrastructure) parity holds — necessary but not sufficient; it proves behavioural equivalence for cases exercised, not the architectural property this PRD exists to prove. The structural tests above are what actually demonstrate self-hosting.
- [ ] Code-review check: `Evaluator` and Rust `kernel/expr.rs` read side by side, list the same short primitive set, with no trace of the larger authoring grammar in either.

## Non-goals

- **No canonical/executable IR abstraction of any kind** (`ExecutableIR`, `ReactionIR`, `KernelIR`, or similar) introduced in this change. That's ADR 0030's territory, to be built only once Expression proves the mechanism. At most an `ExecutableExpression`-shaped name, if a name is needed for this alone.
- **`Binding`, `Reaction`, `ReactionContext`, `PolicyInterpreter`, `SagaInterpreter`** — untouched, even where a related cleanup looks obvious mid-implementation. Record the idea; leave the code. (`Binding` is PRD 10 / ADR 0030 Slice 2, after this lands.)
- **Queries, `goal`, or any other Bluebook construct.**
- **Any extension to Bluebook's own grammar or vocabulary** beyond the minimum needed to declare the expression algebra — don't grow the DSL just to make this PRD more convenient.

## Acceptance statement

Expression structure and derived composition now have one source of truth. Ruby and Rust representations are generated from that definition. Each runtime hand-implements only the irreducible expression semantics. No canonical/executable IR framework beyond Expression is introduced in this change.
