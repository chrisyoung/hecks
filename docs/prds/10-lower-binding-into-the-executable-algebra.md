# PRD 10 — Lower `Binding` into the executable algebra (ADR 0030 Slice 2)

**Status:** Core lowering/resolution shipped (2026-08-20) in both Ruby and Rust, hand-written, unit-tested against real interpreter branch order — see "What shipped," below, for the one honest gap (no generator yet, unlike PRD 09's `Operator`). Depended on nothing PRD 09 didn't already ship — reuses its admitted `Expression` algebra as the substrate, per ADR 0030's own prediction that `Expression` would turn out to be the one genuinely load-bearing primitive.

## The problem

Unlike Expression (PRD 09 — a working self-hosted mechanism with a real gap to close), `Binding` has **no lowering mechanism at all today**, in either direction. Its canonical shape is declared twice, byte-identical, in `lib/hecksagain/language/bluebook/reaction.bluebook`:

```ruby
value_object "Binding" do    # Policy, line 61; ProcessManager, line 166 — identical
  attribute :key,   String
  attribute :value, String
end
```

But `{key, value}` is not what actually resolves a binding at dispatch time — the *real* resolution logic is procedural Ruby, hidden inside two interpreters, each independently:

- `PolicyInterpreter#trigger_args` (`policy_interpreter.rb:198-221`): `value.is_a?(Symbol) ? payload[value] : value` — a 2-way branch (Symbol → look up in the merged event-payload-plus-fan-out-row; anything else → literal).
- `SagaInterpreter#dispatch_args` (`saga_interpreter.rb:260-273`): `!value.is_a?(Symbol) ? value : (value == pm.correlation_head ? correlation : (event.payload.key?(value) ? event.payload[value] : instance[:memory][value]))` — a 4-way branch (literal; or Symbol resolved against, in order, the correlation head, the event payload, or accumulated saga memory).

Nothing about *how* a binding resolves is represented as data — it's entirely encoded in which Ruby method runs, which is exactly why Rust has **zero** representation of `Binding`, `with_spec`, or trigger/dispatch argument resolution at all today, not even a stub. This is the real target for ADR 0030's Slice 2: not "port this logic to Rust by hand" (which would just be a third hand-authored copy of the same resolution rules, the exact failure mode ADR 0030 exists to avoid), but "lower canonical `Binding` into an executable form that names its resolution strategy as data, so both runtimes read the same thing."

## Approach

1. **Canonical `Binding` stays exactly as declared** — `{key, value}`, unchanged, still author-facing as `sets :with_spec, append: { key: :key, value: :value }` in both `Policy.Bind` and `ProcessManager::Dispatch.Bind`. This PRD does not touch the Bluebook grammar.

2. **Design the executable form as `{destination, source}`**, where `source` is an `Expression` node — reusing PRD 09's admitted algebra rather than inventing a second resolution language:
   - A canonical `value` that isn't a Symbol lowers to `Expression::Literal`.
   - A canonical `value` that is a Symbol lowers to `Expression::Reference` — but *which* source it resolves against (payload / correlation head / memory) depends on which sources are actually available to the surrounding reaction, which is exactly the `Context` question ADR 0030's Slice 3 raises for `Reaction`. Slice 2 does **not** decide that question — it takes the *ordered list of available named sources* as an input to lowering, and encodes the priority order (`Reference` tries each source in turn, first match wins) as structure, not as procedural branching. This keeps the lowering pure and testable without touching `PolicyInterpreter`/`SagaInterpreter`/`Reaction` at all, per ADR 0030's explicit instruction to leave `Reaction` untouched during this slice.

3. **The lowering function is the one handwritten bridge, and stays small enough to read end to end** — `lower_binding(canonical_binding, available_sources:)`. ADR 0030's own warning applies directly here: if this function grows into something that re-derives resolution semantics rather than mechanically restructuring already-declared information, Slice 2 has failed on its own terms (a "second compiler hidden inside lowering").

4. **Generate, don't hand-write, both runtimes' executable-node representations** from one definition of the executable `Binding` shape — matching PRD 09's own pattern (`bin/expression_projection` / `bin/project_kernel_capabilities`), not diverging from it. Whether that definition lives in the same `expression.bluebook` chapter (a `Binding` aggregate beside `Operator`/`Normalisation`) or a sibling chapter is an open question below, not decided here.

5. **Prove it with synthetic sources, not a live interpreter.** Test `lower_binding` and its executable-side evaluator against hand-built `available_sources` hashes (`{payload: {...}}`, `{correlation: "x", payload: {...}, memory: {...}}`), not by wiring into `PolicyInterpreter`/`SagaInterpreter`. Wiring the real interpreters to use the lowered form is explicitly **out of scope** — see "Non-goals."

## Acceptance criteria

- [x] A canonical `Binding` (`{key, value}`) lowers deterministically to an executable form (`{destination, source}`) via one small, inspectable function — `Hecksagain::Bluebook::Expression::BindingLowering.lower` (Ruby), `kernel::binding::lower` (Rust), both under 20 lines.
- [x] The lowering function contains no resolution logic of its own — every actual decision (which source wins, in what order) is data it restructures, not logic it invents. Read end to end in one sitting on both sides.
- [x] Both a literal `value` and a Symbol `value` lower correctly, the Symbol case producing a `Reference` ordered exactly the way `dispatch_args`'s real branch order does (correlation head, then payload, then memory) when all three sources are available, and exactly the way `trigger_args` does (payload only) when just one is — asserted directly in both test suites.
- [ ] The executable `Binding` shape has one generated Ruby representation and one generated Rust representation, from one source definition — **not shipped**. Both sides are hand-written mirrors of each other today, the same honest state PRD 09 started from for `Expression` before that ledger existed. See "What shipped."
- [x] A small, standalone evaluator (Ruby and Rust) resolves an executable `Binding` against a given `available_sources`/`sources` map and produces the same value `trigger_args`/`dispatch_args` would — proven with hand-built cases shaped after the real branch order, not the literal `@registry.policy_dispatch_log`/`saga_dispatch_log` entries (those are populated only by a live dispatch; no checked-in fixture file of them exists to read from, so the tests construct the same shapes by hand instead — see "What shipped" for why this is a fair substitute, not a shortcut).
- [x] Existing Ruby-side corpus/fuzzer/behaviors suites remain green (1574 examples, 0 failures, local suite) — this PRD adds a parallel lowering path; it does not change `PolicyInterpreter`/`SagaInterpreter`'s actual dispatch behaviour.
- [x] `cargo build`/`test`/`clippy` clean (20 Rust tests, 3 new).

## What shipped

**The lowering and resolution mechanism, in both languages, hand-written:** `lib/hecksagain/bluebook/expression/binding_lowering.rb` (`ExecutableBinding`/`Literal`/`Reference`, `lower`/`resolve`) and `rust/src/kernel/binding.rs`, structural mirrors of each other. Both take an explicit ordered `priority`/source list as an argument rather than knowing anything about correlation heads or saga memory — `Reaction`/`ReactionContext` stay untouched, per the Non-goals. Ruby: 9 spec examples, all passing, each shaped after a real `trigger_args`/`dispatch_args` branch. Rust: 3 unit tests covering the same three real cases (literal passthrough, correlation-wins-over-payload-and-memory, falls through to nil on a genuinely absent name).

**Not shipped: generation.** Unlike PRD 09's `Operator`, there is no self-hosted `Binding` ledger, no `bin/`-style generator, and no `bin/rust_kernel_coverage`-style mechanical check tying the two implementations together. This is a real gap against this PRD's own fourth acceptance criterion, left open rather than quietly declared done — closing it means designing what a self-hosted `Binding` declaration would even look like (a new aggregate beside `expression.bluebook`'s `Operator`/`Normalisation`? a sibling chapter?), which PRD 10's own Approach named as an open question rather than answered. Until that exists, Ruby's and Rust's `Literal`/`Reference` shapes are two hand-authored copies of the same small structure — low risk given how small and stable that structure is, but exactly the pattern ADR 0022/0030 exist to avoid at scale, worth closing before this becomes a third or fourth hand-copied pair somewhere else.

**Fixtures: hand-built, not lifted from a log.** `@registry.policy_dispatch_log`/`saga_dispatch_log` are populated at real dispatch time, not checked into the repo as a fixture file — there was nothing to literally read from. Both test suites instead construct `sources`/`available_sources` inputs matching the exact field names and structure those logs record (confirmed by re-reading `trigger_args`/`dispatch_args` at implementation time, not assumed from the earlier PRD draft), which satisfies the spirit of "test against real shapes" even though the letter of the original acceptance criterion (reuse the logs themselves) wasn't literally possible.

**Deliberately not attempted:** wiring `PolicyInterpreter`/`SagaInterpreter` to actually use this lowering in place of their own `trigger_args`/`dispatch_args` — per the Non-goals, unchanged.

## Non-goals

- **Wiring `PolicyInterpreter`/`SagaInterpreter` to use the lowered form instead of their own `trigger_args`/`dispatch_args`.** That's a real behaviour change to production dispatch, a much larger and riskier step than proving the lowering mechanism works — and ADR 0030's own six-risk framework treats "does the runtime actually get simpler" (risk 5) as `Reaction`'s question, not `Binding`'s. This PRD proves risks 3–4 (can canonical lower into executable without becoming a second source of truth; does executable stay smaller) — nothing more.
- **`Reaction`, `ReactionContext`, or any interpreter merge/extraction from ADR 0029.** Untouched, per ADR 0030's explicit instruction for this slice.
- **Deciding how `Context`/`available_sources` gets determined at real dispatch time** (i.e., how a live `Reaction` knows whether it's correlated). That's Slice 3's question; this PRD only needs `available_sources` as an *input*, supplied by the test, not derived.
- **A canonical `Binding` aggregate in the grammar**, beyond what's strictly needed to declare the executable-side shape for generation. If the existing `value_object "Binding"` declarations already suffice as the canonical source, don't add a parallel one just for symmetry with `Operator`/`Normalisation`.
