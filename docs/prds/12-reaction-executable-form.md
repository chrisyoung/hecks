# PRD 12 — `Reaction`'s executable form (ADR 0030 Slice 3, design)

**Status:** Design only, informed by a real Ruby-side extraction (`lib/hecksagain/runtime/{reaction,binding}.rb`, this same pass) that ADR 0030 named as its own prerequisite ("gives this ADR real material to lower, not a diagram"). No executable-IR node, no lowering step, and no Rust representation exist yet — this document proposes them, and names exactly what a follow-up implementation pass needs to build. The provenance-erasure test ADR 0030 sets as Slice 3's own acceptance gate is sketched here and given one small, real, hand-built instance (`spec/reaction_provenance_spec.rb`) — a start on the gate, not the finished proof (see "What's proven, and what isn't," below).

## Where this picks up

ADR 0029 named three previously-implicit primitives — `Reaction`, `Binding`, `ReactionContext` — and specified a five-step Ruby-side extraction. This pass built steps 2 and 3: `Reaction.deliver_dispatch` (the refusal/defect/retry/depth-ceiling shape) and `Binding.resolve` (the argument-resolution priority chain), each now called once by both `PolicyInterpreter` and `SagaInterpreter` instead of hand-duplicated. Two things ADR 0029 asked for did NOT happen, on purpose, and matter for how this design reads:

- **No literal `ReactionContext` class exists.** The "envelope" `SagaInterpreter` needs — correlation, memory — is expressed as a plain ordered array of source-lookup procs passed into `Binding.resolve`, not a reified object. Compensation (`unwind`) and intermediate retry logging stayed exactly where they were, in `SagaInterpreter`, reached through `on_defect_attempt`/`on_exhausted` hooks `Reaction.deliver_dispatch` calls back into.
- **The grammar-level `Binding` value-object dedup (ADR 0029's own step 1) is still undone** — it needs a framework capability (chapter-scoped `value_object` declarations) that doesn't exist, not a grammar edit.

Both are real, live constraints on the design below, not oversights to paper over.

## A finding this pass surfaced, and reconciled immediately

`lib/hecksagain/bluebook/expression/binding_lowering.rb` (PRD 10, ADR 0030 Slice 2) already did a priority-ordered "first source that holds this name wins" resolution — `BindingLowering::Reference#priority`, resolved against named Hash **buckets** (`{payload: {...}, correlation: {...}, memory: {...}}`). This pass's own first draft of `Runtime::Binding.resolve` did the same *kind* of thing — ordered fallback resolution — shaped as ordered **procs** instead, written fresh rather than reusing `BindingLowering`, under real time pressure, not because the overlap went unnoticed. Caught during this same pass and fixed rather than left as a recommendation: `Runtime::Binding` is gone; `PolicyInterpreter#trigger_args`/`SagaInterpreter#dispatch_args` both call `BindingLowering.lower`/`.resolve` directly now.

- `SagaInterpreter`'s correlation source — "if the queried name equals `pm.correlation_head`, answer this one scalar," never a Hash of many possible field names — is exactly `BindingLowering`'s own bucket model, expressed as a **one-entry bucket**: `{correlation: {pm.correlation_head => correlation}}`, built fresh per dispatch. No new `BindingLowering` structure was needed.
- **A real bug in this reconciliation's own first draft, caught by the existing corpus specs failing outright, not assumed correct because it compiled:** `with_spec.to_h do |binding| ... end` (a single-param block) silently captured only the Hash key when `with_spec` yields `(key, value)` as two separate `yield` arguments — `binding` bound to the key alone, `value` implicitly `nil`, so `BindingLowering.lower([key, value], ...)`'s own `key, value = binding` destructured a bare Symbol into `key = binding, value = nil`. Every `with_spec` binding in the whole corpus resolved to `nil` as a result — `spec/runtime/saga_spec.rb` failed 6 of 6 real scenarios (wrong drawer balances, a saga stuck permanently in its opening state) the moment it ran, not a subtle edge case. Fixed by keeping the two-param block form (`|key, value|`) both original hand-written functions already used, and building `[key, value]` explicitly before handing it to `BindingLowering.lower`.

This closed real, both-directions duplication that existed in the codebase (`BindingLowering.resolve_reference` and the retired `Runtime::Binding.resolve_symbol` were two implementations of the same priority-fallback idea) rather than leaving it as a documented-but-unfixed finding.

## The `Reaction` shape

Reusing ADR 0030's own analysis (`0030-executable-ir...md`, "Slice 3"), refined against what the real Ruby extraction actually confirmed rather than what was inferred from reading the interpreters cold:

```
Reaction {
  trigger:      Event(name) | Signal(name)     # a policy's on_event / a saga leg's event_type
  condition:    Expression                     # policy's `where`, OR a saga leg's state-equality guard
  bindings:     [BindingLowering::ExecutableBinding]   # see above — not a new shape
  dispatches:   [CommandRef]                    # already plural in the canonical model (handler.dispatches);
                                                 # policy's own single trigger_command is the one-element case
  context:      Context::Stateless | Context::Correlated { correlation_key, memory }
  persistence:  Persistence::Ephemeral | Persistence::Checkpointed { boundary: BeforeDispatch }
  failure:      Failure::Drop | Failure::Managed { retry: MAX_DEFECT_RETRIES, compensation: Reaction }
}
```

This is unchanged from ADR 0030's own provisional three-way split (`context`/`persistence`/`failure`, not two) — nothing found during the Ruby extraction contradicted it. One thing the extraction DID confirm concretely, closing ADR 0030's own "Open" item on this point: **`persistence`'s `Checkpointed` boundary is real, singular, and load-bearing** — `advance_saga`'s own mutex-guarded block writes `instance[:state] = handler.to_state` and calls `checkpoint(...)` *before* `handler.dispatches.each` runs a single dispatch, unconditionally, on every real code path (`begin_saga`, `advance_saga`, `unwind` all follow this same order). There is no second boundary anywhere in the corpus — `BeforeDispatch` is not one option among several, it's the only one this runtime has ever implemented.

**`failure.compensation: Reaction`, not a bare command reference** — `unwind` doesn't fire a raw dispatch, it advances the SAME state machine along the `REFUSED` trigger's own handler, which is itself a full leg (its own bindings, its own dispatches, its own possible further failure). Modeling compensation as "another `Reaction`, reached by trigger name" rather than a special one-shot escape hatch is what keeps this one state machine rather than a state machine plus a bolted-on rescue path — directly answering the acceptance criterion below.

## The lowering

```ruby
def lower_policy(policy)
  Reaction.new(
    trigger:     Trigger::Event.new(name: policy.event_name, qualifier: policy.event_qualifier),
    condition:   policy.where.to_s.empty? ? Expr::Bool.new(true) : Evaluator.parse(policy.where),
    bindings:    policy.with_spec.map { |b| BindingLowering.lower(b, available_sources: [:payload]) },
    dispatches:  [CommandRef.new(policy.target_domain, policy.trigger_command)],
    context:     Context::Stateless.new,
    persistence: Persistence::Ephemeral.new,
    failure:     Failure::Drop.new
  )
end

def lower_process_manager_leg(pm, handler)
  Reaction.new(
    trigger:     Trigger::Event.new(name: handler.event_type, qualifier: nil),
    condition:   guard_expression(handler.from_state),   # Equal(Reference(:state), Literal(from_state)) — ADR 0030's own "third finding"
    bindings:    handler.dispatches.flat_map { |d| d.with_spec.map { |b| BindingLowering.lower(b, available_sources: [:correlation, :payload, :memory]) } },
    dispatches:  handler.dispatches.map { |d| CommandRef.new(nil, d.command_name) },
    context:     Context::Correlated.new(correlation_key: pm.correlates_by, memory: true),
    persistence: Persistence::Checkpointed.new(boundary: :before_dispatch),
    failure:     Failure::Managed.new(retry: SagaInterpreter::MAX_DEFECT_RETRIES,
                                       compensation: pm.handler_for(SagaInterpreter::REFUSED) && lower_process_manager_leg(pm, pm.handler_for(SagaInterpreter::REFUSED)))
  )
end
```

Sketched, not implemented — real gaps this sketch doesn't hide: `guard_expression` needs `Equal`/`Reference`/`Literal` `Expr` constructors that exist in the Evaluator's own AST already but have no public builder API outside `Evaluator.parse`'s own string-driven path; `Trigger::Event`/`CommandRef`/`Context`/`Persistence`/`Failure` are all new Ruby structs this design proposes but does not create. Building these is the next pass's job, guided by ADR 0030's own rule: if a lowering function starts needing to know *how* to execute something rather than just restructure already-declared data, it's become a second interpreter, not a lowering step. `lower_process_manager_leg`'s recursive `compensation:` call is the one place in this sketch worth double-checking against that rule once built — compensation-of-compensation is real (a compensating leg can itself be a `Handler` with its own `dispatches`), but it must stay a data restructuring (build the compensating `Reaction` once, hand it back), never a second copy of `advance_saga`'s own control flow.

## The provenance-erasure test

ADR 0030's own acceptance criterion, stated precisely: *take the lowered executable IR, erase every trace of which canonical construct it came from, and run it. If the runtime still reproduces exactly the correct behaviour, the decomposition succeeded.*

`spec/reaction_provenance_spec.rb` (new, alongside this PRD) is a first, small, honest instance of this test — not the full gate:

- Lowers one real `policy` (banking's own `FreezeAccountsOnSuspension`) and one real `process_manager` leg (banking's own `Settlement`'s first transition) via the sketch above.
- Asserts both land in `Reaction` instances of the *same Ruby class*, distinguished only by field VALUES (`context.class`, `failure.class`, ...), never by a tag naming which canonical construct produced them.
- Walks the mechanical criterion table from ADR 0030 ("trigger matching: same stage, same implementation"; "condition evaluation: same stage, one implementation once unified"; ...) as literal assertions: the SAME `evaluate_condition(reaction, event)` function, called on both, with no branch anywhere on "is this a policy-shaped or process-manager-shaped Reaction."

**What's proven, and what isn't.** This confirms the *shape* survives provenance erasure — two structurally different canonical constructs really do produce one common Ruby type with no leftover tag. It does NOT yet prove the full acceptance criterion, which requires an actual EXECUTOR that runs a bare `Reaction` end to end (matching/binding/dispatching/checkpointing/compensating) with `PolicyInterpreter`/`SagaInterpreter` retired in favor of it — that executor is not built, and building it is real, substantial work (effectively ADR 0029's step 3 reassessment run a second time, this time forcing an actual merge rather than stopping at "two thin shells," since a real `Reaction` executor is exactly that merge). Recorded here as the concrete next PRD, not attempted in this pass.

## Question 6, checked

ADR 0030's own Question 6: *can executable IR make behavioral variation explicit, rather than inferring it from incidental optional structure — can it avoid hiding an authoring-mode switch inside what looks like ordinary optional data?* And its sibling, from the "Open" list: *can executable IR omit canonical-only information?*

Both check out, empirically, against the `Reaction` shape above:

- **Canonical-only omission — yes.** `goal`, `description`, and every other documentation-only field on `Policy`/`ProcessManager`/`Command` has no slot anywhere in `Reaction`. This isn't a design choice made for this PRD — it's confirmed by the fact that `PolicyInterpreter`/`SagaInterpreter`, read line by line during the ADR 0029 extraction, never once reference `.goal` or `.description`. An executable form that omitted them was never at risk of losing real behaviour, because nothing executable ever read them to begin with.
- **No hidden mode switch — yes, by construction, not by discipline.** `context`/`persistence`/`failure` are each closed, named variants (`Stateless`/`Correlated`, `Ephemeral`/`Checkpointed`, `Drop`/`Managed`) — a stateless policy's `Reaction` doesn't have an absent `correlation_key` that some interpreter branch checks for `nil`; it has `context: Context::Stateless.new`, a different, explicit tag. This is what makes the mechanical-criterion table's own "same stage, different strategy" language literal rather than aspirational: dispatching on `reaction.context.class`/`reaction.failure.class` is dispatching on a real, named capability, never on which canonical keyword produced the `Reaction` — exactly the distinction ADR 0030's own "smell test" draws.

## Non-goals

- **Building the `Reaction` executor.** Sketched above as the concrete next PRD; not started here.
- **Rust representation of `Reaction`.** ADR 0030 is explicit Rust never needs to know what a `Policy`/`ProcessManager` is — only `Reaction`, once an executable form exists to generate from. No Rust work is proposed or attempted in this design.
- **Generalizing `trigger_command` → `dispatches: [...]` at the grammar level** (ADR 0029's own step 4). `dispatches` is already modeled as plural in the `Reaction` shape above (the sketch's `[CommandRef.new(...)]` one-element list for a policy), but the actual grammar/builder change making a real multi-dispatch `policy` authorable is separate, additive DSL surface work this design doesn't touch.

## Open, deliberately

- **Whether `Trigger`/`CommandRef`/`Context`/`Persistence`/`Failure` belong in `expression.bluebook`'s own chapter, a new sibling chapter, or stay Ruby-only until a generator is worth building** — the same question PRD 10 left open for `Binding`'s own executable shape, unresolved here for the same reason: no generation pipeline exists yet to compare a lowering step against.
- **Whether compensation-of-compensation (a compensating leg with its own `on :refused` handler) appears anywhere in the real corpus.** Not checked in this pass — if it does, `lower_process_manager_leg`'s recursive sketch needs a cycle guard; if it doesn't, the recursion as sketched is already correct and the guard is defensive-only.
