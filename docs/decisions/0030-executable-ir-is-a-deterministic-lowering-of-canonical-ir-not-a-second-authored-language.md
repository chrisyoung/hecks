# Executable IR is a deterministic lowering of canonical IR — not a second authored language

**Status:** Proposed — pending review. Written alongside ADR 0029 because the two share one seam (`Reaction`/`Binding`) but are separable pieces of work — 0029 is a Ruby-side interpreter extraction with a five-step sequencing plan; this ADR's own proof sequence is two slices, Expression then Binding, deliberately stopping short of `Reaction` until both hold — see "Proof sequence," below.

## Context

ADR 0029 found that `goal` carries real domain meaning (a command's human-readable intent) and requires zero runtime behaviour — it's read by `docs_projector.rb`/`cli_projector.rb`, never by an interpreter. That's a small fact about one field. The larger fact it exposes: **every field the Ruby grammar declares is currently assumed, by construction, to be something every runtime — including Rust — must eventually understand.** Nothing in the codebase says otherwise; ADR 0022's framing of its own problem ("self-host the expression grammar," i.e. all of it) inherits that assumption without stating it.

That assumption is expensive in a specific way ADR 0022 already documents: `rust/src/kernel/expr.rs` is a hand-port of Ruby's `Evaluator`/`Resolver` — "two independently authored implementations of the same small, *closed* grammar." The fix ADR 0022 proposes (self-host the expression grammar so both are checked against one shared description) is correct as far as it goes, but scoped to expressions alone it leaves the same question open one level up: is `policy`, `process_manager`, `goal`, and everything else in `reaction.bluebook` also something Rust must eventually mirror? If the answer stays "yes, eventually," Rust's obligation only grows as the language does.

## Decision

### The pipeline has two IRs, not one, and a single lowering step between them

```
Bluebook DSL
     ↓  (author, parse)
Canonical IR
     ↓  (lower — the ONE handwritten semantic bridge)
Executable IR
     ↓  (decode, execute — generated/generic on both sides)
Ruby kernel · Rust kernel · WASM kernel
```

**Canonical IR** is the complete semantic description of a domain — everything a bluebook means, including its own documentation of itself: `goal`, `description`, story/rationale, documentation metadata, projection metadata. This is what exists today; nothing about it changes.

**Executable IR** contains only what a runtime must actually execute: `Command`, `Event`, `Reaction` (ADR 0029's primitive), `Query`, `Expression`, and whatever `Reaction`'s own context requires (`ReactionContext`, `Binding` — see "How small," below). `Policy` and `ProcessManager` do not appear in it at all — both lower to `Reaction`, distinguished only by whether their context is stateless or correlated:

```
canonical                              executable
Policy {                               Reaction {
  on: LoanApproved                       trigger: Event(LoanApproved)
  dispatch: FundAccount        lowers    condition: True
  mappings: ...                  →       bindings: [...]
}                                        dispatches: [FundAccount]
                                         context: Stateless
                                       }

ProcessManager { ... }        lowers    Reaction {
                                 →         trigger: ...
                                           condition: ...
                                           bindings: ...
                                           dispatches: ...
                                           context: Correlated {
                                             key: ..., memory: ...,
                                             retry: ..., compensation: ...
                                           }
                                       }
```

Once this lowering exists, Rust has no reason to know what a `Policy` or a `ProcessManager` is — it only ever sees `Reaction`.

### The criterion for which side a field lands on

For every canonical field, ask: **could removing this field change the externally observable execution of the domain?**

- **No → canonical-only.** `goal`, `description`, rationale, documentation labels, projection metadata.
- **Yes → executable.** Command arguments, event structure, reaction trigger, binding expressions, conditions, correlation semantics, retry semantics, compensation semantics, query definitions.

This is the same test, applied one layer up, as ADR 0026's "the language uses everything it declares" — 0026 asks whether the *language itself* uses a construct; this asks whether *execution* does. A field can pass 0026's bar (used somewhere, by something) and still fail this one, exactly as `goal` does: used by the docs projector, never by execution.

### The one hard constraint: this must not become a second authored language

The entire value of this split depends on Executable IR being a **deterministic projection** of Canonical IR — never a second source of truth. The failure mode is concrete and specific: hand-write a canonical model, hand-write a lowering step, then hand-write a Ruby evaluator for the executable model *and* hand-write a Rust evaluator for it too. That's not two interpreters becoming one boundary — it's one interpreter becoming three, with the same "kept in agreement by discipline, not by construction" problem ADR 0022 already lives with, now duplicated across an extra layer.

What makes the split pay for itself is a single self-hosted definition of the **executable semantic algebra** — an `executable.bluebook`, in this codebase's own idiom — from which Ruby's executable-node representation, Rust's, encoding/decoding, and validation are all generated or generic, the same way ADR 0022 already proposes for expressions alone:

```
executable.bluebook
        ↓
grammar / generated model
        ├── Ruby executable nodes
        ├── Rust executable nodes
        ├── encoder / decoder
        └── validation
```

Counted this way, there are three places semantics live, not four: **(1)** the Bluebook authoring parser, **(2)** the canonical→executable lowering (the one handwritten semantic bridge — it belongs in exactly one place, on the Ruby/authoring side, and nowhere else), **(3)** the executable kernel, shared across runtimes through generated structures and a small evaluator. If a fourth hand-authored thing appears anywhere in that chain, this decision has failed on its own terms.

### The warning sign to watch for

If `executable.bluebook` starts acquiring `policy`, `process_manager`, `goal`, `workflow`, or anything else that reads as an authoring convenience rather than an execution primitive, that is Bluebook being recreated underneath Bluebook — the second-authored-language failure mode, arrived at by accretion rather than by decision. The executable algebra should stay close to boring: `Reaction`, `Expression`, `Binding`, `Invocation`, `Query`. If it stays that small, the boundary is in the right place.

### How small the executable algebra might actually be

`Reaction`'s fields (ADR 0029: trigger, condition, bindings, dispatches, optional context) are already executable structure on their own. Two of them may not deserve independent primitive status:

- **`Condition` may just be `Expression` typed to a boolean result** — not a distinct kernel concept.
- **`Binding` may just be `{destination, Expression}`** — a small program, not a structural primitive of its own.

If both hold up under scrutiny, the executable kernel reduces to something close to: `Command`, `Event`, `Reaction`, `Query`, `Expression`, `Context`. That would make **`Expression` the one genuinely load-bearing, irreducible primitive** — it's the shared substrate for conditions, bindings, query predicates, correlation keys, and plausibly future authorization predicates. Which is also exactly the piece ADR 0022 already found duplicated and already proposed self-hosting. Read this way, ADR 0022 wasn't solving a narrow problem — it was starting on the one piece of the executable algebra most worth starting on. This ADR reframes its target accordingly: not "self-host the expression grammar" but **"self-host the executable semantic algebra, starting with `Expression` because it's already duplicated and already the load-bearing primitive."**

### The boundary this must not cross: deployment stays out

Executable IR answers only *what behaviour a runtime must realize* — never *how it's delivered*. A `Reaction` says "on event A, if expression B, bind values C and issue command D." It must never say "send D over MQTT to device 17," which HTTP endpoint served the request, which Postgres table backs a query, a thread count, a Lambda ARN, or a WASM memory layout. Those stay exactly where hecksagain already puts them — in ports, adapters, and the `.hecksagon`/`.world` wiring layer (the same separation `README.md`'s three-file split already draws: `.bluebook` is "the domain... No I/O, no config"; `.hecksagon` is "the wiring... override, not substrate"). This ADR does not touch that boundary; it names a second one, one layer further in, between the domain's full meaning and the slice of it a runtime executes.

### What this does for Rust and WASM specifically

Once Rust consumes Executable IR rather than parsing Bluebook toward a full canonical model, it never needs to carry `goal`, documentation, stories, authoring concepts, projection metadata, or discipline metadata — not as fields it ignores, but as concepts its parser and structs never mention at all. Concretely:

```
Ruby / authoring side                    Rust
Bluebook → Canonical IR                  decode Executable IR
  → validate / analyze                     → execute
  → lower to Executable IR
  → serialize (binary / JSON)
```

Smaller structs, a smaller parser, smaller binaries, less validation, less memory, less parity surface to keep in sync — the last of these being the direct payoff against ADR 0022's actual complaint. A full Rust consumer of the *canonical* model may still be worth having for tooling/projection use cases, but that is a different layer from the runtime kernel — conceptually `hecks-ir` (full canonical) vs. `hecks-exec-ir` (tiny executable) vs. `hecks-kernel` (executes exec-ir), without committing yet to three actual crates.

## Proof sequence — Expression, then Binding, then, only if both hold, Reaction

Five distinct risks are actually in play here, not one ("can a generator emit structs of different shapes," which is ordinary codegen and proves nothing):

1. Can one definition encode executable semantics precisely enough?
2. Can Ruby and Rust consume generated artifacts without adding handwritten semantic branches?
3. Can canonical IR lower into executable IR without becoming a second source of truth?
4. Can the executable representation stay smaller than canonical IR?
5. Does the resulting runtime actually get simpler?
6. Can executable IR make behavioral variation explicit, rather than inferring it from incidental optional structure — i.e., can it avoid hiding an authoring-mode switch inside what looks like ordinary optional data?

No single construct tests all six, and jumping straight to `Reaction` — the most complex candidate — would confound them if it failed. Neither Expression nor Binding can even expose risk 6: both are pure evaluation/resolution with no temporal behaviour and no optional sub-structure whose presence silently changes what runs. Three ordered slices isolate the risks instead of confounding them.

### Slice 1 — Expression alone (this is ADR 0022, reframed as a slice rather than a standalone fix)

**Correction, added after inventory (PRD 09):** most of this slice already exists and already works. `lib/hecksagain/grammar/expression.bluebook` self-hosts an `Operator`/`Normalisation` admission ledger (propose → render per target → admit), replayed by `spec/operator_conformance_spec.rb`, generating both Ruby's `projection.json` (`bin/expression_projection`) and Rust's `OperatorCategory` enum (`bin/project_kernel_capabilities`) from one source — correctly, for 18 operators across 7 categories, with `bin/rust_kernel_coverage` mechanically checking every admitted category has a hand-written Rust interpretation file. The diagram below is what that mechanism already does. What's still genuinely open, and what PRD 09 actually scopes: twelve operator symbols (`.match?`, `.present?`/`.blank?`, `.split`, `.first`/`.last`, `.start_with?`/`.end_with?`, `.all?`/`.any?`/`.none?`, `.find`) were added to Ruby's `Resolver` outside this ledger entirely and have zero Rust representation — a real, live gap in an otherwise-working mechanism, not evidence the mechanism needs to be built. Separately, `Expr` itself (the Rust enum) stays hand-written even for admitted operators — generating it too remains open and is not what PRD 09 attempts.

```
executable expression definition
        ↓
generate Ruby node model / evaluator
generate Rust node model / evaluator
        ↓
retire handwritten Ruby/Rust duplication
        ↓
verify against the existing corpus + fuzzer parity
```

`Reaction` stays untouched during this slice. Expression proves risks **1** and **2** only — it cannot test the canonical→executable *lowering* boundary at all, because canonical and executable Expression are already nearly identical; a pass here could accidentally prove nothing more than "we can generate two expression evaluators from one grammar."

**Success criteria:** one source definition; zero handwritten parallel expression grammar; same observable behaviour, same failures/refusals, same serialization shape as today.

**The generate/handwrite boundary, stated as a mechanical rule, not a preference:** a generator owns *structure*; a handwritten evaluator owns *meaning*. `Expr = LessThan(lhs, rhs) | Equal(lhs, rhs) | And(lhs, rhs) | Or(lhs, rhs) | Not(expr) | Literal(value)` is declarative — the Ruby node model, the Rust enum, codecs, visitors, and validation all generate cleanly from it. What `LessThan(a, b) => compare(resolve(a), resolve(b))` *means* does not — that's interpretation, and stays a small, explicit, handwritten evaluator per runtime even at 50 lines, unless the executable definition already carries independent declarative semantics powerful enough to make generating the evaluator purely mechanical. The test for whether a definition has crossed that line: if an operator's definition is structural (`name: less_than, arity: 2, result: boolean`), generate from it; the moment it needs `implementation: lhs < rhs` or a per-target `ruby:`/`rust:` code string, the grammar has started becoming an interpreter or a code-template language, and that's the second-authored-language failure mode arriving through the generator instead of through hand-authoring. Stop before that line, not after.

**The one legitimate exception — reduction, not implementation.** ADR 0029/0022 already note the expression grammar has "six operators, reduced to two primitives (`less_than`, `equal`) combined with a small boolean algebra." Those reductions are themselves declarative and *can* be generated: `greater_than(a, b) = less_than(b, a)`; `not_equal(a, b) = not(equal(a, b))`; `less_than_or_equal(a, b) = or(less_than(a, b), equal(a, b))`. That splits every operator into one of two buckets:

- **Primitive semantics** — `equal`, `less_than`, `resolve`/reference, boolean composition (`and`/`or`/`not`). Irreducible; hand-implemented once per runtime.
- **Derived semantics** — `greater_than`, `<=`, `>=`, `!=`, compound boolean forms. Expressible purely as composition of the primitives; generated, never hand-implemented.

Which sharpens the pipeline:

```
self-hosted expression definition
        ↓
generated node types
generated normalization / reduction     (derived → primitive composition)
        ↓
tiny handwritten evaluator
        ↓
irreducible primitives: resolve, equal, less_than, boolean composition
```

**The acceptance test, stated honestly rather than absolutely:** the bar is not "adding any operator touches exactly one file, no matter what" — that bar, taken literally, would eventually pressure the grammar into carrying executable semantics just to satisfy it, which is exactly the failure mode above. The honest version: *adding syntax or a derived operator requires one definition change and regeneration; adding genuinely new primitive semantics requires one definition change plus one small, explicit implementation per execution engine.* `contains` is the live diagnostic for telling which case a new operator is: if it lowers into existing primitives (a composition, like the `<=` example above), it's derived — one definition edit, generated everywhere. If it doesn't, it introduces real new runtime meaning, and both runtimes legitimately need a small hand-written implementation of it — that is not a failure of self-hosting, it's an honest count of where semantics actually live. Keep using `contains` (or whatever the next proposed operator turns out to be) as this test as the executable algebra grows.

**The metric that actually matters is semantic implementation count, not evaluator line count.** Two 35-line evaluators, one per runtime, operating over identical generated node sets and implementing only `resolve`, `equal`, `less_than` — three tiny primitives — is a healthy outcome even though 70 handwritten lines exist. A single "fully generated" evaluator produced by an increasingly clever metagrammar is the less healthy outcome, even at a smaller line count, because the semantics moved into the grammar to get there. Slice 1's success is measured by counting irreducible hand-implemented primitives per runtime, not by counting deleted lines.

**This same rule transfers to Binding and Reaction, unchanged.** For `Binding {destination, expression}`, representation and codecs generate; the operation itself (`value = evaluate(binding.expression, context); assign(binding.destination, value)`) stays handwritten and generic, because it's interpretation regardless of how few lines it takes. For `Reaction`, the shape — how triggers match, how bindings evaluate, how commands dispatch — generates; kernel semantics (what retry or compensation actually *does*) stays handwritten, unless a given behaviour reduces to composition of already-existing primitives, in which case it's lowered before runtime rather than re-implemented. The decision tree is the same at every layer: **can this be derived solely from declared structure or composition? Generate/lower it. Does it require defining what an operation means at runtime? Handwrite it as a kernel primitive. Would generating it require embedding target-language code or templates in the grammar? Stop — the interpreter has moved into the grammar.**

**Revised acceptance bar for this slice, replacing the looser version above:** one source of expression structure; one source of derived-operator definitions; generated, equivalent Ruby/Rust representations; no handwritten duplicated grammar; a deliberately tiny, explicit, handwritten primitive evaluator per runtime; corpus/fuzzer parity.

### Slice 2 — Binding, deliberately not Reaction, as the first real lowering test

```
Canonical Binding { key, value/source, ... }
        ↓ lower_binding(...)   — the one handwritten bridge, kept tiny and inspectable
Executable Binding { destination, expression }
        ↓
generated Ruby / Rust representation
        ↓
kernel execution
```

`Binding` is chosen deliberately over `Reaction` for this slice: it is the smallest construct that genuinely exercises canonical→executable *lowering* (risk **3**) rather than pass-through, and it's small enough that if the architecture turns out wrong here, nothing large has been committed to it. It also happens to be immediately useful regardless of outcome — ADR 0029 already found `Binding` duplicated byte-for-byte between `Policy` and `ProcessManager`, so this slice is simultaneously an architecture experiment and a real cleanup.

**The design constraint that makes this a fair test:** `lower_binding` must stay small and obviously correct on inspection — mostly discarding canonical-only information and normalizing equivalent authoring shapes. The failure mode to watch for is a large lowering function that secretly re-implements Bluebook semantics — a second compiler hidden inside "lowering," which is the second-authored-language risk arriving through the back door rather than the front.

Success here proves risks **3** and **4**.

### Stop-condition check, run honestly (2026-08-20) — Reaction does not start yet

PRD 09 (Expression) and PRD 10 (Binding) both shipped, verified, on the correct branch. The stop condition above exists precisely so shipping isn't mistaken for passing it — run here rather than skipped:

| question | answer | why |
|---|---|---|
| Did handwritten Rust shrink? | **No** | PRD 09 *added* four new hand-written category files (`regex.rs`, `presence.rs`, `string.rs`, `accessor.rs`) and a new dependency; PRD 10 added `binding.rs`. Both were real, correct additions — closing a coverage gap and building a mechanism that didn't exist — but neither is a *reduction*. |
| Did handwritten Ruby shrink? | **No** | Same shape: `binding_lowering.rb` is new code, not a replacement for `trigger_args`/`dispatch_args`, which PRD 10's own Non-goals explicitly left untouched. |
| Did duplicated grammar disappear? | **No, and Binding added a fresh instance of it.** ADR 0022's original complaint — Ruby's `Evaluator`/`Resolver` and Rust's `expr.rs` as two hand-authored implementations of the same closed grammar — still fully stands; PRD 09 closed an *admission* gap, not that duplication. PRD 10 is more pointed: `binding_lowering.rb` and `binding.rs` are two hand-authored mirrors of the exact same small structure, flagged honestly in both files' own headers and in PRD 10's "What shipped," but duplicated all the same. |
| Is there exactly one semantic definition? | **No** — for Binding, explicitly two. For Expression's *newly admitted* operators, also two (hand-written on both sides; only the *category roster*, not the node logic, generates). |
| Is the lowering step visibly simpler than the representation it produces? | **Not yet meaningfully testable** — no generation pipeline exists for `Binding` to compare a lowering step against; `lower()` is small, but "simpler than what it produces" presumes there's a generated artifact on the other side, and there isn't one yet. |
| Can executable IR omit canonical-only information? | **Untested** — neither slice's work involved a canonical-only field (`goal`-shaped) to check this against. |

**Six questions, zero clean yeses.** Per this ADR's own text: *"If not, this ADR needs rethinking before anything larger lands on top of it."* `Reaction` does not start from this state. This is not a failure of PRD 09/10 — both did exactly what they set out to do, honestly, and PRD 09 in particular *did* prove the underlying claim (generation without duplication) is achievable, just for the *pre-existing* 18 operators, not the ones either PRD touched. What's missing before `Reaction` is warranted: an actual generator for `Binding` (PRD 10's own still-open acceptance criterion), and ideally the same for the newly-admitted Expression operators — closing the *new* duplication both slices honestly flagged, rather than adding `Reaction`'s much larger surface on top of a foundation that hasn't cleared its own bar yet.

**Decided:** the next increment is closing PRD 10's open generation gap, not starting Slice 3.

### Reassessment (same day) — `Binding`'s structural gap closed; one bar was mis-stated, one remains genuinely open

`bin/project_binding_shape` now generates `rust/src/kernel/binding/mod.rs` from one manifest (`BindingShape`), with Ruby's own structs checked equal to it — closing PRD 10's specific open item. Re-running the table above with that change requires correcting how it was read the first time, not just updating one row: **"is there exactly one semantic definition"** was answered as a single yes/no when this ADR's own Slice 1 section already drew the real distinction — *structure* must not duplicate; *meaning* (the tiny handwritten evaluator per runtime) is expected to, by design, per "generate structure, handwrite meaning." Read correctly:

- **Structure** — `OperatorCategory` (PRD 09, pre-existing) and now `Source`/`ExecutableBinding` (PRD 10) both have exactly one generated source. This bar is **met**, for everything either slice actually touched.
- **Meaning** — `expression_operators/*.rs` and `binding/logic.rs` are hand-written once per runtime, matching Ruby's own hand-written `Resolver`/`BindingLowering` logic. This is **not a gap** — it's the architecture working as designed. The `lower()`/`resolve()` pair being short and inspectable (PRD 10's own acceptance bar) is what makes duplicating them safely tolerable, the same reasoning that makes a 7-primitive expression evaluator tolerable to hand-write twice.

What this reassessment does **not** change: `rust/src/kernel/expr.rs`'s `Expr` enum and Ruby's `Evaluator`/`Resolver` node set are still two independently hand-authored implementations of the *original*, larger closed grammar — ADR 0022's own complaint, predating both PRDs, untouched by either. That's the one piece of "did duplicated grammar disappear" that's still a real *structural* duplication, not a design-accepted one, and it's the one both "did handwritten Rust/Ruby shrink" questions were really gesturing at. Neither PRD 09 nor PRD 10 set out to fix it (PRD 09's own Non-goals name it explicitly: "generating the `Expr` enum itself... remains open, genuinely harder, work"), so its persistence isn't a new finding — but it does mean the honest state is **structure-duplication is resolved for what these two slices cover; the original, larger structural duplication is unresolved and unattempted.**

**Still decided: `Reaction` does not start yet.** Not because PRD 09/10's own work is incomplete — it isn't, by its own bar — but because starting Slice 3 on top of an `Expr`/`Evaluator`/`Resolver` foundation that still has ADR 0022's original duplication live would mean building `Reaction`'s executable form (which itself leans on `Expression` as its load-bearing primitive, per this ADR's own earlier reasoning) on a substrate that hasn't cleared this ADR's own bar. Generating `Expr` itself — the genuinely harder work both PRDs deferred — is the realistic next gate, not a third structural-generation exercise at Binding's smaller scale.

### Final reassessment (same day) — PRD 11 closes the *original* ADR 0022 complaint; the stop condition, re-run

PRD 11 did what the reassessment above named as the realistic next gate: `rust/src/kernel/expr.rs` (flat, 319 lines, hand-typed `Expr` enum inline) became `rust/src/kernel/expr/{mod.rs, logic.rs}` — `mod.rs` generated from `NodeShapeRust` (itself checked against `NodeShape`, itself checked against the real `Evaluator`/`Resolver` structs), `logic.rs` carrying `interpret`/`category_of`/`dispatch_operator`/`Value`/`Field` unchanged. The generated enum matched the original hand-typed one exactly, variant-for-variant, on first generation — and 16/16 real scenarios in `spec/rust_conformance_spec.rb` (the compiled Rust binary against real generated domains, not just unit tests) passed unchanged. Re-running the six questions:

| question | answer | why |
|---|---|---|
| Did handwritten Rust shrink? | **Yes — the first time in this whole sequence.** `expr.rs`'s hand-typed 34-line enum is now 50 lines of *generated* `mod.rs`, never hand-edited again; `logic.rs` (268 lines) is the same logic, unchanged, just relocated. |
| Did handwritten Ruby shrink? | **No, and correctly so.** `Evaluator`/`Resolver`'s structs were never the problem — they're already the simplest possible spelling of the shape. `NodeShape`/`NodeShapeRust` are new *checking* code, not a reduction; generating Ruby's own structs too would add a build step without reducing real risk, the same call PRD 10 already made for `Binding`. |
| Did duplicated grammar disappear? | **Yes, for the original complaint specifically.** `Expr` and `Evaluator`/`Resolver`'s node shapes are no longer two independently hand-authored declarations — one manifest chain drives the generated Rust side, checked bidirectionally against the real Ruby side. This is the piece both PRD 09 and PRD 10 explicitly deferred as "genuinely harder work," now closed. |
| Is there exactly one semantic definition? | **Yes, for structure** (the bar this question actually means, per the corrected reading above) — met for `Expr` now, not just for `OperatorCategory`/`Binding`. **Meaning stays hand-written twice, by design** — not a gap, the same architecture the whole proof sequence is built on. |
| Is the lowering step simpler than what it produces? | **Yes** — `NodeShapeRust` (≈115 lines of flat field declarations) plus `bin/project_expr_shape` (≈95 lines, written once) together generate and will *keep* generating the enum correctly as it grows, versus hand-maintaining a 34-line block that has to be kept in sync with Ruby by discipline alone. |
| Can executable IR omit canonical-only information? | **Still untested.** No canonical-only field (`goal`-shaped) was involved in any of the three PRDs. The one honestly open question left. |

**Five of six, clean — the sixth was never in scope for any of the three PRDs to test, not evidence against them.** The original ADR 0022 diagnosis — Ruby and Rust as two independently hand-authored implementations of the same closed expression grammar — is retired for the node-shape/structure layer specifically, verified against real running domains, not asserted.

**Decided: `Reaction` may start.** The substrate this ADR withheld it from — `Expr`/`Evaluator`/`Resolver` still structurally duplicated — no longer exists. Question 6 (canonical-only omission) stays open and should be the first thing `Reaction`'s own design checks against, since `Reaction`'s own canonical form is exactly where a `goal`-shaped field would first appear — but it's a design input for Slice 3, not a blocker to starting it, the same way it was never blocking PRD 09/10/11 either.

### Slice 3 — Reaction is the real stress test (cleared to start — see the reassessment immediately above; the design/risk analysis below stands unchanged)

`Reaction` tests risk **5** (does the runtime actually get simpler) — meaningful only once 1–4 are independently retired — but it also introduces a risk Expression and Binding structurally cannot expose: **behavioral mode coupling.**

`Reaction`'s optional sub-structure is not itself the problem — "generate structure, handwrite meaning" covers `Reaction { trigger, condition, bindings, dispatches, context? }` exactly as cleanly as it covers everything else. The risk appears the moment runtime semantics become *implicitly determined by the presence or absence of that structure* — an interpreter shaped like `if context: checkpoint; retry; compensate; resolve from memory / else: log-and-drop; resolve from payload` has stopped treating `context?` as optional data and started using it as a hidden mode switch, secretly running two different interpreters under one construct name.

**Correction to "one execution protocol":** that's the wrong shape to aim for. `process_manager`'s real behaviour — a retry re-enters dispatch, compensation invokes a whole separate leg, checkpointing happens at a specific transition boundary, accumulated memory feeds later resolution — is not a linear pipeline with optional steps. It's a state machine, with real branches and real cycles:

```
Triggered → Matched → BindingsResolved → Prepared → Dispatching
                                                       /  |  \
                                                     ok refusal defect
                                                      |     |      |
                                                      ↓     ↓      ↓
                                                  Commit  Handle  Handle
                                                            |       |
                                                       compensate?  retry?
                                                            |       |
                                                    compensation    └──→ back to
                                                       reaction          Prepared/Dispatching
```

A stateless `policy` takes the *shortest path* through this same machine — it doesn't run a different, simpler machine. That reframing matters: aiming for "one linear sequence" would either force saga semantics into a fake pipeline wearing flags, or (worse) produce two pipelines wearing one name. Aiming for one state machine, where a stateless reaction just skips optional states rather than needing a different machine, is the honest target.

**The smell test, sharpened.** Conditionals are not the problem — `if failure_policy.retry?(defect)` and `if context.correlated?` are completely legitimate; something has to decide which capability applies. The smell is a branch on construct *origin*, or its disguised equivalent:

```
# fine — each branch is a real, named capability
context.load(...)
binding.resolve(...)
failure_policy.handle(...)

# the smell — direct or disguised
if reaction.origin == :process_manager
  execute_saga_way(...)
else
  execute_policy_way(...)
end
```

The disguised form is the one worth watching for: `if context.correlated? / 80 lines of process-manager execution / else / 30 lines of policy execution` is the same smell as the direct form, wearing a capability check as camouflage. The real question for any branch: does it correspond to an independent, named executable capability, or to which authoring keyword produced this `Reaction`?

**A concrete finding from the real code, not a hypothesis: checkpoint timing is semantic, and checkpoint may not be a `failure_policy` property at all.** `resolve → checkpoint → dispatch` and `resolve → dispatch → checkpoint` are not equivalent — the first records intent before an external effect and recovers differently from a crash than the second, which records completion after one. Reading `saga_interpreter.rb#advance_saga` (ADR 0029's own citation) settles which one hecksagain actually does: the state transition and its checkpoint happen *once*, inside the mutex, immediately after `instance[:state] = handler.to_state` and strictly *before* `handler.dispatches.each` runs any dispatch. Intent is durably recorded first; the external effects follow. That's a fact to preserve in the executable form, not a design choice up for grabs — and it argues for a third, independent dimension rather than folding checkpoint into failure handling:

```
Reaction {
  trigger, condition, bindings, dispatches,
  context:     Context::Stateless | Context::Correlated { correlation, memory },
  persistence: Persistence::Ephemeral | Persistence::Checkpointed { boundary: BeforeDispatch },
  failure:     Failure::Drop | Failure::Managed { retry, compensation }
}
```

Correlation doesn't logically require checkpointing; checkpointing doesn't logically require managed failure handling. They travel together today only because one keyword (`process_manager`) bundles all three — which is a fine authoring convenience and a bad executable-semantics assumption. (Named provisionally — per "make real variation explicit, don't parameterize hypothetical variation," below, this three-way split shouldn't be taken as settled until it's checked against what the code actually varies, not just this reading of it.)

**A second concrete finding: multi-dispatch failure semantics, also read from the real code rather than assumed.** `handler.dispatches.each { |spec| deliver_saga_dispatch(...) }` does not stop at the first failure — every dispatch in a leg is attempted independently, in declaration order, regardless of an earlier one's outcome. Each dispatch's *own* refusal, or its own exhausted retries, independently triggers `unwind` (compensation) against the *shared correlated instance* — not "compensate just that dispatch," not "abort the remaining dispatches," and retry (`MAX_DEFECT_RETRIES`) is scoped to that one dispatch's own attempt, never the whole leg. **Do not design a `DispatchPlan` primitive (`sequential`, `failure: stop`, etc.) to cover this** — that would be parameterizing a variation nothing in the corpus actually exercises. The one behaviour that exists — independent attempts, shared-instance compensation on any failure, per-dispatch retry — should simply be *named* as the `dispatches` stage's actual semantics, not left as a knob nobody turns.

**A third finding, closing a gap rather than opening one:** policy's `where` (an arbitrary boolean `Expression`) and a process-manager leg's guard (`instance[:state] == handler.from_state`, a bare equality check) look asymmetric — one general, one narrow — until the guard is read as what it actually is: `Equal(Reference(:state), Literal(handler.from_state))`, an ordinary instance of the same `Expression` primitive Slice 1 already builds, just always instantiated the same way. Read this way, `condition` doesn't need two mechanisms; it needs one (`Expression`), with a process-manager's guard as a specific, common shape of it rather than a structurally different check. This is exactly the kind of thing the mechanical criterion below exists to catch.

**The mechanical criterion, applied to what's actually different between the two interpreters today** (from `policy_interpreter.rb`/`saga_interpreter.rb`, ADR 0029's own reading):

| concern | policy | process manager | changes a stage's behaviour, or the transition graph? |
|---|---|---|---|
| trigger matching | event name | event name | same stage, same implementation |
| condition evaluation | arbitrary `Expression` (`where`) | state-equality (a narrow `Expression`, see above) | same stage, one implementation once unified |
| argument resolution | payload / literal | correlation-head / payload / memory | same stage, different strategy |
| correlation | none | yes, mutex-guarded | `context` strategy |
| checkpoint | none | once, before dispatch (confirmed above) | `persistence` strategy, but *fixed boundary* — not itself a free parameter |
| dispatch cardinality | one | many, independent (confirmed above) | same stage; `dispatches` is already plural in ADR 0029's design |
| refusal | drop (log, stop) | compensate (`unwind`) | `failure` strategy |
| defect | one attempt, drop | retry (×3), then compensate | `failure` strategy |
| depth ceiling | drop | compensate | `failure` strategy — same outcome class as refusal/defect, not a fourth case |
| state commit | none | exact point: with the checkpoint, before dispatch | `persistence` strategy |

Every row here changes what a stage *does* via a named strategy, not *when* stages run or which stages exist — which is the good outcome the criterion is checking for. If a future row instead changed the transition graph itself (a strategy that requires jumping to a different point in the state machine depending on another strategy's value), that would be evidence the two-or-three-strategy model is insufficient and the interaction needs modelling as explicit named transitions instead — still one `Reaction` state machine, but a real transition machine rather than a pipeline with parameterized callbacks. And if inspection ever turns up two largely disjoint transition graphs rather than one machine with strategy-varied stages, that's a legitimate result too — evidence `Reaction` was too aggressive a collapse, feeding back into ADR 0029's own framing, not a failure of this ADR's method.

**The shared skeleton this suggests** (a shape to test against the table above, not a design to build ahead of it): accept event → match reaction → acquire execution context → evaluate guard → resolve bindings → enter execution boundary (checkpoint, if `persistence` says so) → dispatch invocation(s) → classify outcome → apply outcome policy (`failure` strategy) → commit/update context → emit resulting events. Policy and process-manager become different *implementations* of the same eleven stages, not different machines. One caveat: if a chosen strategy for one stage ever needs to change *where* another stage occurs, rather than only what it does, stage-parameterization has stopped being sufficient, and the actual transitions need to be modelled explicitly rather than assumed independent.

**The acceptance criterion for this slice, stated precisely:** `Reaction` defines one explicit execution state machine. Optional capabilities may enable or bypass states and alter transitions, but no transition may depend on whether the canonical source construct was a `policy` or a `process_manager`. **The concrete test:** take the lowered executable IR, erase every trace of which canonical construct it came from, and run it. If the runtime still reproduces exactly the correct behaviour, the decomposition succeeded. If it needs to know where the `Reaction` originated, the authoring model has been smuggled back into the kernel.

**The progression, restated with all three slices:** Expression proves generated executable structure can drive two real runtimes (risks 1–2). Binding proves canonical semantics can lower into that structure without becoming a second source of truth (risks 3–4). Reaction proves the executable algebra can represent real temporal/control semantics — a genuine state machine, not a pure function — *without recreating the authoring constructs it's supposed to have replaced* (risks 5–6). That's a materially higher bar than either earlier slice, and the reason `Reaction` stays last regardless of how well Expression and Binding go.

**Stop condition, checked after Slice 2, before Reaction starts:** did handwritten Rust shrink? Did handwritten Ruby shrink? Did duplicated grammar disappear? Is there exactly one semantic definition? Is the lowering step visibly simpler than the representation it produces? Can executable IR omit canonical-only information? If every answer is yes, proceed to `Reaction`. If not, this ADR needs rethinking before anything larger lands on top of it.

**A second stop condition, specific to Reaction and checked only once a design exists:** does the provenance-erasure test above pass? If yes, this ADR has produced something more significant than a code-generation cleanup — a credible small executable algebra beneath Bluebook. If no, the decomposition isn't finished, and the design needs another pass before it's trusted, not shipped as a "close enough" approximation.

## Update, 2026-08-20 — PRD 12: `Reaction`'s design exists; the extraction it depends on shipped; the provenance-erasure test has a first, real instance

ADR 0029's own `Reaction`/`Binding` extraction — this ADR's own named prerequisite ("gives this ADR real material to lower, not a diagram") — is real now (ADR 0029's own update, same day). **PRD 12** (`docs/prds/12-reaction-executable-form.md`) is the design this ADR called for: a concrete `Reaction { trigger, condition, bindings, dispatches, context, persistence, failure }` shape, two lowering functions (`lower_policy`, `lower_process_manager_leg`), and a hand-built, minimal instance of the provenance-erasure test itself (`spec/reaction_provenance_spec.rb`) — run against REAL canonical data (a real banking `policy` and a real `Settlement` process-manager leg), not synthetic fixtures.

**What it actually proves, stated precisely, not overclaimed:** the SHAPE survives provenance erasure — a real policy and a real process-manager leg genuinely lower into instances of one Ruby class, distinguished only by field values (`context`/`persistence`/`failure`'s own named variants), never by an origin tag, and the same `evaluate_condition` function runs both a policy's `where` and a saga leg's state-equality guard with no branch on which canonical construct produced either. It does NOT yet prove the ADR's own full second stop condition — that needs a real EXECUTOR (matching/binding/dispatching/checkpointing/compensating a bare `Reaction`, with `PolicyInterpreter`/`SagaInterpreter` retired in its favor), which doesn't exist. PRD 12 names building that executor as its own next PRD.

**Question 6, this ADR's own long-open item, checked empirically rather than left open further:** yes on both halves. Canonical-only fields (`goal`, `description`) omit cleanly — `Reaction` never had a slot for either, confirmed by the fact that neither interpreter, read line by line during the ADR 0029 extraction, ever referenced them. No hidden authoring-mode switch either — `context`/`persistence`/`failure` are closed, explicitly-tagged variants (`Context::Stateless`/`Context::Correlated`, ...), never an absent field a branch checks for `nil`.

**A real, unplanned finding surfaced and closed in the same pass:** PRD 10's own `BindingLowering` (Slice 2) and ADR 0029's own fresh `Binding`-resolution extraction turned out to be two Ruby implementations of the identical priority-fallback idea, written independently under time pressure rather than reconciled on sight. Reconciled immediately rather than left as a documented gap — `PolicyInterpreter`/`SagaInterpreter` call `BindingLowering` directly now, and the interim module is gone. The fix caught a real bug (a block-arity mistake that silently nulled every real `with_spec` in the corpus) via the existing corpus specs failing outright, not via inspection.

## Consequences

- **This is architecture with a proof sequence, not a task list.** The three slices above are validation gates, not a full implementation plan for `Reaction` — a concrete design for `Reaction`'s executable form belongs in a follow-up, written only after Slice 2's stop condition passes and after ADR 0029's own `Reaction`/`Binding` extraction gives this ADR real material to lower.
- **`ReactionContext`'s bundling (correlation + memory + retry + compensation, ADR 0029) is provisional at the executable-IR layer, not settled by that ADR.** It's the right call for a same-behaviour Ruby-side extraction; whether the executable algebra keeps it as one capability or splits it into orthogonal ones — the working hypothesis in Slice 3 is three (`context`, `persistence`, `failure`), not two, once checkpoint timing turned out to be its own semantic dimension — is exactly what Slice 3 tests, checked against the mechanical criterion's table, not designed ahead of it.
- **ADR 0022 is reframed, not superseded.** Its diagnosis (duplicated hand-authored `expr.rs`/`Evaluator`) stands; its remedy is now understood as step one of a larger, still-bounded target rather than a complete fix on its own.
- **The single-lowering-step discipline is the whole risk.** If the lowering step or the executable-node representations end up hand-duplicated per runtime after all, this decision has produced a fourth interpreter instead of removing duplication — the "warning sign" above is the concrete thing to check for during implementation, not just at design time.
- **Rust's obligations shrink, but only once this is built.** Until the lowering step and a self-hosted executable algebra exist, Rust still mirrors whatever Ruby's canonical model contains, same as today.

## Open, deliberately

- **Whether `Condition` and `Binding` survive as named primitives or fully reduce to `Expression`-shaped structures.** Argued for reduction above; Slice 2 is exactly the test — its outcome answers this for `Binding` directly and for `Condition` by close analogy.
- **Where the lowering step physically lives** — inside the existing Ruby projector framework (`lib/hecksagain/projector/`, already the seam ADR 0027 names for canonical-IR consumers) or a new, dedicated module. Leaning toward the projector framework, since it already exists to consume canonical IR toward a target; not decided.
- **Whether `hecks-exec-ir`/`hecks-kernel` ever become real, separate crates**, versus staying a conceptual boundary inside the existing `rust/` layout. No pressure to decide before the self-hosted algebra exists to put in them.
- **Serialization format for Executable IR crossing the Ruby→Rust boundary** (binary vs. JSON) — a real decision with WASM-size consequences, deferred until there's an executable algebra to serialize.

## Rejected alternatives

- **Leaving canonical and executable concerns conflated**, on the theory that ADR 0022's expression self-hosting alone is enough. Rejected because it fixes one duplicated evaluator while leaving the assumption that caused it — everything declared is everything every runtime must understand — fully in place, ready to cause the same problem again the next time the grammar grows.
- **A canonical/executable split built from hand-written models on both sides**, i.e., without a self-hosted executable algebra generating both runtimes' representations. Rejected as the specific failure mode this whole decision exists to avoid — it would not reduce duplication, it would relocate it one layer deeper and add a translation step on top.
- **Deciding `Condition`/`Binding`'s final shape now**, before any of this is built. Rejected as premature — ADR 0029's extraction hasn't happened yet, and this ADR's own criterion (does removing it change observable execution) is best applied to real code, not to a diagram.
- **Starting the proof sequence with `Reaction`**, on the reasoning that it's the construct that actually matters. Rejected because `Reaction` is complex enough to confound multiple risks at once — a failure there wouldn't distinguish "the lowering architecture is wrong" from "`Reaction` specifically is hard to lower." Expression and Binding isolate risks 1–4 cheaply before anything is staked on the construct risk 5 actually cares about.
- **Generating the evaluator implementation itself from the executable grammar**, rather than generating node types/codecs with one small handwritten evaluator walking them. Rejected as a default — legitimate only if the grammar genuinely carries enough semantic information to generate evaluation cleanly, which is a per-operator judgment call, not a blanket strategy. Defaulting to full generation risks turning the self-hosted schema into a programming language in its own right, which is the second-authored-language failure mode arrived at through the generator instead of through hand-authoring.
