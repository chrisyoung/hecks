# The reaction shape is `policy` and `process_manager`; they converge into one interpreter; `service`, `workflow`, `requires`, `acts_as`, and `cadence` are not built

**Status:** Proposed — pending review. Written before any code changes, per instruction to cover the whole disposition in the plan before executing any of it, with rewriting the runtime explicitly in scope — this is not a reuse-only plan. The Bluebook DSL surface is out of scope for change: `policy` and `process_manager` stay two distinct author-facing keywords with their own grammar. What changes is that they stop being two independently hand-authored interpreters underneath.

## Context

A reduction of eleven words — `policy`, `service`, `workflow`, `process_manager`, `cadence`, `trigger`, `for_each`, `requires`, `role`/`acts_as`, `goal`, `report` — was proposed as a single shape, `signal + predicate → command`, with a few of them (`report`) sitting outside it as `state → data`. Measured against the actual grammar (`lib/hecksagain/language/bluebook/*.bluebook`) and runtime (`lib/hecksagain/runtime/*.rb`) rather than against the abstraction, the words split three ways:

| word | status | evidence |
|---|---|---|
| `policy` | **real, minimal** | `policy_interpreter.rb` — event name + optional `where` (`Bluebook::Expression::Evaluator`) → `@door.reenter(target, ...)`. No dead branches. |
| `for_each` | **real, layered on `policy`** | `policy_interpreter.rb:92,155-176` — a second delivery path (`deliver_for_each`) sharing `policy`'s event/`where` test, adding query resolution + per-row `addressing_key_for` + per-row dispatch. Not a bare tag: ~80 lines of its own failure handling. |
| `role` | **real, already generic** | `command_rules/authorization.rb#refuse_role_mismatch`, one step in the shared `DISPATCH_ORDER` pipeline (`command_interpreter.rb:65-66`), checked via `Ports::Authorization.holds_role?`. Every command in `reaction.bluebook` carries it. |
| `process_manager` | **real, currently a separate interpreter — convergence candidate** | `lib/hecksagain/bluebook/process_manager.rb`, `saga_interpreter.rb` (298 lines), `registry/saga_persistence.rb` (correlation-keyed memory `policy` has none of). Grammar (`reaction.bluebook:116-322`) is a full state machine: `states`, `correlates_by`, `starts_on`, `ends_on`, nested `Handler` entities (`event_type`, `from_state`→`to_state`) each holding nested `Dispatch` entities with their own bindings. Read closely, `saga_interpreter.rb` and `policy_interpreter.rb` share most of their real work — see "Rewrite," below — and only genuinely diverge on three things: correlation-keyed persisted state, automatic compensation (`unwind`) on refusal, and defect retry (`MAX_DEFECT_RETRIES`). |
| `trigger` | **real, narrower than proposed** | `vocabulary.bluebook:329-331`: `value_object "Trigger"` is a closed one-member enum, `{"refused"}` — names a process manager's compensating leg (`on :refused`), not a general "external signal → command" primitive. |
| `goal` | **exists, inert** | Required string on every `command` (`bluebook/command.rb:97`), consumed only by `docs_projector.rb:248` and `cli_projector.rb:191` as human-readable text. No interpreter reads `.goal`. It is documentation, not the predicate-over-state the reduction proposed. |
| `report` | **dead name** | `syntax.bluebook:326` — `member word: "read_model", ..., was: "report"`. The construct is live; the word `report` is retired. |
| `cadence` | **not built** | Zero grammar footprint. Every repo hit is a domain author's own attribute name (`StatementFrequency#cadence`, `RecurringPayment#cadence`) — user data, not language vocabulary. |
| `requires` | **not built under that name** | No command-guard construct named `requires`. The one `requires:` in the codebase is an unrelated projector-framework kwarg (`projector/target.rb:73`, naming a Ruby module a doc target needs loaded). The job the reduction assigns to `requires` — a condition gating command execution — is already `given`/`where`, evaluated by the same shared `Evaluator` `policy`'s `where` uses (ADR 0009: *"held as data, never as an evaluator... with no self-hosted 'Interpreter' construct"*). |
| `service` | **not built** | Zero grammar footprint anywhere in `lib/`, `docs/`, `rust/`. Every hit is the ordinary English word. |
| `workflow` | **not built** | Zero grammar footprint. Every hit is ordinary English ("the Rust generator's workflow"). |
| `acts_as` | **not built** | Zero hits anywhere, of any kind. |

So the reduction's real content is smaller than eleven words: two live interpreter shapes (`policy`, `process_manager`), one real combinator on the first (`for_each`), one attribute already correctly generalized (`role`), one construct doing this job under a different name (`given`/`where` standing in for `requires`), one dead name (`report`), one inert word masquerading as behaviour (`goal`), and four words with no runtime referent at all (`service`, `workflow`, `acts_as`, `cadence`).

This matters because "collapse eleven primitives to a few" was never actually on offer as originally framed — four of the eleven words were never built, so there was nothing there to collapse. But the two words that *are* real, `policy` and `process_manager`, turn out to be the same design hand-authored twice with one genuine extra capability grafted on — which is exactly the kind of thing worth rewriting. The real plan is: **converge `policy` and `process_manager` onto one interpreter, close out the dead/inert names, and refuse to build the four words that would only duplicate what the converged interpreter and `role`/`given` already do.**

## Decision

### Keep unchanged — already minimal

- **`policy`** stays exactly as implemented at the grammar level: `event + optional where → command`. Its *interpreter* is in scope for the rewrite below, but its declared shape is not changing.
- **`for_each`** stays as a delivery mode on `policy`, not promoted to its own aggregate. It already shares `policy`'s event/`where` test and adds only what fan-out genuinely requires (query resolution, per-row addressing). Splitting it out would duplicate that shared test for no gain. Whether it generalizes to correlated reactions too is noted under "Open," below — no corpus evidence demands it yet.
- **`role`** stays a plain attribute on `command`, checked by the one existing `DISPATCH_ORDER` step. This already *is* "a predicate over actor + context, gating a command" — the shape the reduction proposed for `acts_as`.
- **`trigger`** stays a closed one-member vocabulary scoped to process-manager compensating legs. Not generalized into a standalone signal primitive — nothing in the corpus needs a second member yet, and a vocabulary of one that has never needed a second member is not evidence a general mechanism is missing.

### Rewrite — converge `policy_interpreter.rb` and `saga_interpreter.rb` into one `ReactionInterpreter`

Reading both interpreters line by line (`policy_interpreter.rb:83-176`, `saga_interpreter.rb:95-273`) shows they are not two designs that happen to overlap — they are the same design, independently hand-authored twice, plus one genuine extra capability grafted onto the second copy. Concretely, near-duplicated between them:

- **The refusal/defect rescue shape.** Both catch `DOMAIN_REFUSALS` as a recorded, non-fatal outcome and `StandardError` as a distinguishable `defect: true` — the exact split, with the exact reasoning ("the triggering command already succeeded and persisted by the time this runs"), spelled out twice (`policy_interpreter.rb:102-136`, `saga_interpreter.rb:172-213`).
- **The reaction-depth ceiling check.** Identical guard (`@door.reaction_depth_reached?` → record `delivered: false` and stop) written twice (`policy_interpreter.rb:95-98`, `saga_interpreter.rb:150-165`).
- **Argument resolution.** `PolicyInterpreter#trigger_args` (2-branch: `Symbol` → payload lookup, else → literal) and `SagaInterpreter#dispatch_args` (3-branch: `Symbol` → correlation-head or payload or accumulated memory, else → literal) are the same function with one extra source ranked into the lookup chain.
- **The `Binding` value object.** Declared byte-identical twice in the grammar itself (`reaction.bluebook:61-64` on `Policy`, `reaction.bluebook:166-169` on `ProcessManager`) — the smallest, lowest-risk instance of the same duplication, fixable independently of everything else here.

What genuinely does not overlap, and must survive the merge as *conditional* behaviour, not be discarded or forced onto the stateless case:

- **Correlation-keyed persisted state** (`@registry.saga_instances`, `saga_mutex`, `checkpoint`) — exists only because a process manager's legs must find each other across separate events. A stateless policy has nothing to key.
- **Automatic compensation (`unwind`)** — fires the `on :refused` handler when a leg refuses, moves state to `to_state` *before* its own dispatches run so a second refusal can't loop. Meaningful only where there is state to unwind; a stateless policy's refusal is already just a logged, non-fatal outcome — nothing moved that needs reversing.
- **Defect retry (`MAX_DEFECT_RETRIES`)** — a saga leg gets three attempts before a crash is compensated; a policy dispatch gets one. This asymmetry is called out in the code as deliberate ("gives a transient failure... a chance to clear on its own") but the reasoning given applies just as well to a stateless policy dispatch. Whether to extend retry to policy or keep the asymmetry is a real behaviour question, not a refactor detail — see "Open," below.
- **Multi-command dispatch per leg** (`handler.dispatches.each`) — a process-manager leg can fire several commands; a policy fires exactly one. Generalizing `policy`'s single `trigger_command` into a `dispatches: [...]` list (grammar-additive: the existing single-target form becomes sugar for a one-element list) gives stateless policies this for free and is what actually retires any need for a separate `service`/`workflow` construct — the "command graph" the reduction wanted `service` for is this list, already built for the stateful case.

**Design:** one `ReactionInterpreter`, parameterized by whether the declaration carries `correlates_by`. Without it, dispatch runs exactly as `PolicyInterpreter` does today (no mutex, no checkpoint, no unwind, current single-attempt defect handling, unless "Open" below changes that). With it, dispatch additionally resolves/creates the correlated instance, checkpoints under the mutex, and on refusal or exhausted retries, unwinds — exactly as `SagaInterpreter` does today. The shared middle (refusal/defect split, depth ceiling, argument resolution, dispatch-list iteration) is written once.

**Sequencing, behaviour-preserving at every step:**

1. **Dedupe the `Binding` value object** in `reaction.bluebook` — grammar-only, zero interpreter risk, ships alone.
2. **Extract the shared refusal/defect rescue and depth-ceiling check** into one module both interpreters call, without merging the classes yet — de-risks by keeping every existing behaviour bit-for-bit identical while removing the duplication that matters most (it's the part most likely to drift, per ADR 0022's own reasoning about duplicated hand-authored logic).
3. **Unify argument resolution** into one function taking an optional correlation/memory context (`nil` reproduces `PolicyInterpreter`'s 2-branch lookup exactly).
4. **Generalize `trigger_command` → `dispatches: [...]`** at the grammar level (additive; existing single-target `policy` declarations parse as a one-element list, no author-visible change) and fold multi-dispatch iteration into the shared path.
5. **Merge `PolicyInterpreter` and `SagaInterpreter` into `ReactionInterpreter`**, correlation-gated as designed above. Verify against the full `.behaviors` corpus and the fuzzer's grammar-claimed properties (ADR 0024's infrastructure) before deleting the old classes — this is the step with real regression risk, and it's the last one.
6. **Retire `policy_interpreter.rb` and `saga_interpreter.rb`** as separate files once parity holds across the corpus.

Grammar keywords (`policy`, `process_manager`, `for_each`, `Handler`, `Dispatch`) are unchanged by all six steps — this is an interpreter convergence, not a DSL change, matching the constraint that the Bluebook surface stays fixed.

### Retire, formally

- **`report` → `read_model`, cleanup pass.** The rename already happened (`syntax.bluebook`'s `was:` column). Before treating this as closed: grep the corpus and docs for lingering `report` usage and confirm none remain outside the historical `was:` annotation itself. This is a sweep, not a design decision.

### Fix or reclassify — pick one before touching `goal`

- **`goal` is currently a lie the grammar tells about itself**: it reads as behaviour (a "goal" sounds like a checkable postcondition) and is decoration (ADR 0025's own bar: *"a word that reads as behaviour must be behaviour"*). Two honest resolutions, not a third that leaves it as-is:
  - **(a) Make it real** — evaluate `goal` as an actual predicate over post-dispatch state (an assertion checked after `apply_mutations`/`advance_lifecycle`, alongside `ensures`), so it does the job the original reduction assigned it.
  - **(b) Rename it to what it is** — a required doc string is a fine thing to require, but call it `description` or fold it into the existing `description` convention aggregates already use (`reaction.bluebook:3`), and stop implying it is checked.
  - This ADR does not pick for you: (a) is new interpreter surface (a second predicate-consumer alongside `ensures`); (b) is a pure rename with no interpreter change. Recorded as **Open**, below — needs a decision before execution, not during it.

### Do not build

- **`service`.** Once `dispatches: [...]` generalizes `policy`'s single target (see "Rewrite," above), a stateless `policy` already covers "one signal → several commands" — the degenerate case of `service` with no `states`/`correlates_by`. Nothing further to build; this falls out of the interpreter convergence rather than needing its own construct.
- **`workflow`.** This is `process_manager` under a different name — event/state graph + conditions → commands is exactly `reaction.bluebook`'s `ProcessManager` shape. After the rewrite it is also, underneath, the same interpreter as `policy`. Building a second construct for the same shape would reintroduce the dual-implementation defect ADR 0022 is actively trying to retire one level down (Rust `expr.rs` vs. Ruby `Evaluator`) — this ADR is not going to open the same defect one level up, especially not right after closing it at the interpreter level.
- **`acts_as`.** Duplicates `role`. If a future need requires more than "one role string, checked for equality," extend `role`'s own semantics (e.g., a closed set, or delegation to `Ports::Authorization`) rather than adding a second construct that means the same thing.
- **`requires`** as a distinct grammar word. `given`/`where` already is this primitive, already runs through the shared `Expression::Evaluator`. If the *word* `requires` is wanted purely for authoring readability (some readers may find `requires` clearer than `given` at a call site), that is pure DSL sugar — an alias resolved by the builder to the same `given` field, zero new interpreter surface — never a second evaluator path.
- **`cadence`.** No scheduling/time-triggered reaction exists today, and none of the corpus's `.bluebook` files need one. If and when one is needed, it should be a new *signal-kind* value alongside `event` on the existing `policy` shape (a `schedule:` field beside `on_event`, read by one new step in `policy_interpreter.rb`'s already-generic dispatch), not a new top-level aggregate — the same way `for_each` extended `policy` instead of becoming its own thing.

## Consequences

- **This is a real rewrite, not a documentation exercise.** `policy_interpreter.rb` and `saga_interpreter.rb` (580 lines together) converge into one `ReactionInterpreter`, in the six behaviour-preserving steps above. Most "do not build" items (`service`, `workflow`, `acts_as`, `requires`, `cadence`) are refusals with no code attached — but `process_manager`/`policy` convergence and the `goal` resolution are not; they are the actual work this plan authorizes.
- **Step 5 (the merge itself) is the one step with real regression risk** — correlation, compensation, and retry are load-bearing production behaviour (`saga_persistence.rb` is what makes a process manager survive a restart). It must hold full corpus/fuzzer parity before step 6 deletes anything, and should be sequenced last for exactly that reason.
- **The DSL surface is unaffected.** `policy`, `process_manager`, `for_each`, `Handler`, `Dispatch`, and every other author-facing keyword keep their spelling and their grammar. This decision is entirely about how many interpreter classes read them — two collapsing to one — not about what an author writes.
- **`policy` gains real capability it didn't have**, once `dispatches: [...]` generalizes its single target: firing several commands from one event, for free, without becoming a process manager. This is a genuine behaviour change to `policy`'s runtime (additive — existing single-target declarations are unaffected) and is what retires the case for `service`.
- **Future scheduling and readability-sugar requests have a pre-decided shape.** When `cadence` or a `requires`-spelling request actually arrives, this ADR is the answer: extend `policy`'s signal-kind, or alias into `given` — do not open a design conversation from scratch.
- **Two open items block calling this plan complete**, both flagged below rather than decided here: `goal`'s disposition, and whether defect retry extends to stateless `policy` dispatches now that the interpreters share a rescue path.

## Open, deliberately

- **`goal`: predicate or rename?** Needs your call — see "Fix or reclassify," above. Recommendation, not a decision: (b), the rename — the corpus's own precedent (ADR 0025) is to demote inert words rather than retrofit behaviour onto them, and nothing in the reduction's motivating cases actually needed `goal` to be checked, only readable.
- **Should defect retry (`MAX_DEFECT_RETRIES`) extend to stateless `policy` dispatches?** Once step 2 of the rewrite shares one rescue path, this asymmetry (sagas retry a crash three times, policies don't) either gets a real justification beyond "the saga interpreter happened to grow it first," or it should extend to both. Recommendation: extend it — the reasoning already on record (`saga_interpreter.rb:187-199`, "gives a transient failure... a chance to clear on its own") names nothing specific to correlation. Needs your call before step 2 lands, since it changes observable behaviour for every existing policy.
- **Whether `for_each` generalizes to correlated reactions**, now that both interpreters share one dispatch path. No corpus case needs a process-manager leg to fan out per row today; noted as available once the merge lands, not proposed as part of it.
- **Whether `requires` is worth adding as pure sugar for `given`.** No corpus evidence anyone has wanted this; noted as available, not proposed.
- **Whether `trigger`'s vocabulary should ever grow a second member.** No current need; the one-member enum stays as documentation-by-construction (ADR 0025's own reasoning for `Trigger`'s comment) until a second compensating case actually appears in a real `.bluebook`.

## Rejected alternatives

- **Building `service`/`workflow`/`acts_as`/`requires`/`cadence` as new top-level constructs**, on the reduction's original framing that each names a distinct shape. Rejected because none adds capability beyond `policy`, `process_manager`, `role`, and `given` as they stand today — building them would be modelling for the abstraction's sake, exactly what ADR 0025 argues against, and would reintroduce the dual-implementation defect ADR 0022 is trying to retire rather than duplicate.
- **Leaving `policy_interpreter.rb` and `saga_interpreter.rb` permanently separate**, treating the overlap documented above as coincidental rather than load-bearing. This was the first draft of this ADR. Rejected once the two files were read side by side: the refusal/defect split, the depth-ceiling check, and the argument-resolution logic are the same design, not a coincidence, written twice under separate names — exactly the pattern ADR 0022 names as the thing worth retiring, one level up from where 0022 itself found it. "It's real code, so leave it" is not, on its own, a reason to keep a duplicate; it's a reason to sequence the merge carefully, which the six-step plan above does.
- **Leaving `goal` exactly as-is, unresolved.** Rejected as an option here, not because inertness is intolerable in general (`Trigger`'s one-member vocabulary is deliberately left sparse), but because `goal` is required on every single command — a mandatory field with no behaviour is a much larger standing claim than an optional, narrow enum, and ADR 0025's own bar applies squarely to it.
