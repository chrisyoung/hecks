# Hecksagain IR & runtime architecture — reference

_2026-08-21._ A summary of what the `Reaction`/`PrimalIR` extraction (ADR
0029, ADR 0030) actually established this pass, measured against real code,
plus one architectural hypothesis the shape suggests but that this work did
not test. Sections 1–4 are implemented, observed, and measured. Section 5 is
a hypothesis implied by that work, not evidence from it — see that
section's own header for why the distinction matters.

## 1. IR naming and boundary

The architecture has two explicitly different intermediate representations:

```
Bluebook
    ↓
BluebookIR
    ↓ handwritten lowering
PrimalIR
    ↓
Ruby / Rust / WASM kernels
```

`BluebookIR` is the canonical representation of everything a Bluebook domain
means. It preserves executable semantics as well as canonical-only
information such as goals, descriptions, provenance, and other information
useful for analysis, documentation, governance, or projection.

`PrimalIR` is the smaller, closed executable algebra produced by lowering
`BluebookIR`. It contains only information capable of affecting observable
execution.

`PrimalIR` is not a second authored language: it has no independent syntax
or authoring identity and is never a competing source of truth. It is
solely the deterministic lowering target of `BluebookIR`.

## 2. Governing architectural rule

> One implementation per irreducible semantic behavior. Orchestration
> remains separate where behavior is genuinely different. Do not optimize
> for class count or LOC at the expense of real semantic boundaries.

A Bluebook construct does not automatically deserve a corresponding runtime
primitive.

Author-facing concepts may lower into compositions of `PrimalIR` primitives.
Conversely, genuinely different orchestration should not be forced into a
universal interpreter merely to eliminate classes.

The objective is therefore not:

- fewest classes
- fewest files
- fewest total LOC

It is:

- fewest independently implemented semantics

Generated LOC, handwritten LOC, runtime primitive count, and binary size
are separate measurements.

## 3. Reaction / Binding extraction

`PolicyInterpreter` and `SagaInterpreter` originally contained independently
implemented versions of several common behaviors.

The extraction identified a shared executable shape centered on:

- `Reaction`
- `Binding`
- `Context`
- `Persistence`
- `Lifecycle`
- `Failure`

Common execution semantics were moved behind `ReactionExecutor`, and
canonical constructs are converted through `ReactionLowering`.

After the lifecycle gap was fixed (`Context::Correlated` gained an explicit
`Lifecycle::Begin`/`Continue`/`End` tag, and `Persistence` gained an
`Ended` variant), a direct comparison found **zero duplicated semantic
algorithms remaining** between `PolicyInterpreter` and `SagaInterpreter`.
Condition evaluation, checkpoint behavior, dispatch, retry, and binding
resolution now have one implementation.

The remaining interpreter responsibilities are genuinely different:

```
PolicyInterpreter
  matching
  for_each fan-out
  stateless orchestration
SagaInterpreter
  correlated instance lifecycle
  mutex/reentrancy boundary
  compensation
```

The shared `Reaction` area is currently 256 handwritten code-only LOC. The
residual interpreters contain approximately 111 LOC for `PolicyInterpreter`
and 163 LOC for `SagaInterpreter`.

Total handwritten LOC increased during the extraction. This is considered
an acceptable result rather than a failed reduction: previously implicit
semantics — particularly lifecycle — became explicit data, while duplicated
semantic implementations were eliminated.

Accordingly, the decision is **not** to build a universal `ReactionRuntime`
merely to delete the two interpreter classes. The current boundary reflects
real differences in orchestration.

## 4. Rust `orchestrate.rs`: next concrete lever

A close reading classified approximately 880 production code lines in
`rust/src/kernel/orchestrate.rs`.

| Category | LOC | Interpretation |
|---|---|---|
| Canonical interpretation | ~230 | Should disappear when Rust consumes lowered `PrimalIR::Reaction` |
| Reaction execution semantics | ~435 | Must exist, but ~150–250 LOC appears to duplicate generic kernel behavior already implemented elsewhere |
| Rust-specific mechanics | ~85 | Legitimately remains |
| Distinct capabilities | ~90 | Legitimately remain outside basic Reaction execution |

The first category includes Rust's independently maintained representations
and interpretation of canonical `Policy`/`ProcessManager` semantics,
including trigger/lifecycle derivation that `ReactionLowering` already
performs.

Within the second category, binding resolution is a concrete, confirmed
duplication: `resolve_with`, `build_dispatch_args`, and `trigger_args`
reproduce behavior already represented by generic binding/reaction kernel
functions (`kernel::binding::resolve`, `kernel::reaction::logic::
resolve_dispatch_bindings`), including the `Bindings::Verbatim` behavior.

The expected result is not elimination of `orchestrate.rs`. Current
evidence supports a credible reduction from roughly 880 production LOC to
approximately **450–550 handwritten LOC**, contingent on closing two
representation gaps without merely relocating equivalent complexity
elsewhere.

### Two `PrimalIR` gaps discovered

**Correlation resolution.** `Context::Correlated` currently carries the
lowered `correlation_key`, but runtime `correlation_of` has a three-tier
fallback requiring the original dotted `correlates_by` path. `PrimalIR`
therefore currently under-specifies information required to reproduce
existing behavior.

**Cross-domain dispatch.** `CommandRef` does not represent that a dispatch
requires host-mediated delivery to another domain. Cross-domain policy
behavior therefore cannot yet be expressed completely as an ordinary
`Reaction` dispatch.

These should be resolved as explicit executable semantics where necessary,
rather than by allowing Rust to recover behavior from canonical provenance.

The intended end state is:

```
BluebookIR
    ↓
ReactionLowering
    ↓
PrimalIR Reaction
    ├── Ruby kernel
    └── Rust kernel
```

Rust should implement `PrimalIR` semantics, not independently reinterpret
canonical `Policy` and `ProcessManager` constructs.

## 5. Agent implications — architectural hypothesis

**The work above was not designed or evaluated as an agent-programming
system.** No comparative testing has established that Hecks is safer,
easier, or more effective for agents than other programming or modeling
approaches. There is currently no basis for claiming Hecks is "the first
programming language for agents" — declarative and constrained languages
suitable for machine generation substantially predate Hecks, and
establishing a meaningful historical "first" would be difficult regardless.

The `BluebookIR` → `PrimalIR` architecture nevertheless suggests a
potentially useful property for agent-mediated development: an agent could
propose changes at the meaning-bearing `BluebookIR` level while executable
behavior remains constrained by the closed `PrimalIR` algebra.

That yields the hypothesis:

> Agents propose meaning; `PrimalIR` constrains execution.

This should be treated as a property to investigate, not as an established
advantage. The boundary it describes:

```
new domain expression
        ↓
lowers to existing PrimalIR?
       /                 \
     yes                  no
      ↓                    ↓
composition of       new executable
known semantics      primitive required
```

An agent could introduce new domain vocabulary without necessarily gaining
the ability to invent new machine semantics. Crossing the `PrimalIR`
boundary by requiring a genuinely new primitive could be treated as an
exceptional, governed change.

**This is unusually testable**, which is what makes it worth stating even
without evidence yet: a later comparison could have agents make the same
domain change through conventional source code versus Bluebook, and measure
invalid changes, semantic violations, new implementation machinery
introduced, repair iterations, and whether changes remain within existing
`PrimalIR` primitives.

Until such a comparison exists, "agent-compatible architecture worth
investigating" is supportable; "better/safer language for agents" is not.
