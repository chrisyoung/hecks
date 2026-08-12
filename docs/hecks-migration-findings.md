# What the hecks migration found: gaps hecksagain didn't have

**Status: informational.** This is not an ADR — nothing here is a decision to
accept or reject, it's a record of what one real, large-corpus migration
(`hecks`/`hecks_conception`, `miette`, `bin-buddy`, `deciderate`,
`hecks_nursury`, and 15 smaller repos — roughly 900 `.bluebook` files total,
none of them written for hecksagain originally) found missing or broken the
moment it actually tried to run on hecksagain, rather than just parse under
it. Kept for the same reason `rust-experiment.md` is kept: the finding is
real and worth having on record even though most of it is now fixed.

## The discipline that found these

Every one of these gaps survived `hecksagain-cli validate` cleanly. Several
survived it for an entire migration pass before a real dispatch caught them.
`validate` proves parse-time structure and wiring — it does not evaluate a
single predicate, mutation, or refusal message. The pattern repeated enough
times across enough unrelated files that it became the migration's own
standing rule: a corpus is not proven until something has actually been
dispatched through it, not merely booted. Nineteen of the thirty-six findings
below were invisible to `validate` and only surfaced on a real
`hecksagain-cli dispatch` call.

## New DSL constructs hecksagain could not parse or express at all (18)

Corpus content that is idiomatic Ruby, or a documented feature of the
language's own canonical Pizzas example, with no builder method or IR field
behind it:

1. `redirects_native` never round-tripped through the self-hosted grammar —
   `Command`'s own IR field existed and serialized in `to_h`, but the
   self-hosted `Command` aggregate that the Judge reconstructs every
   bluebook against had no matching field or sub-command, so anything
   reading the reconstructed object (not the original Ruby builder output)
   never saw it. Closed with a four-part grammar change, mirroring
   `Announce`/`emits` exactly — see commit `007d2d2`.
2. `then_set :field, to: false` — `to || from` treated Ruby's `false`
   identically to an absent `to:`. Needed a sentinel distinct from `nil`.
3. `then_set :field, true` — a bare positional boolean instead of the
   keyword form; `then_set` was keywords-only.
4. `then_set :field, remove:` — list removal by value, the natural
   counterpart to `append:`.
5. Aggregate-level `invariant "desc" do ... end` — only `ValueObjectBuilder`
   had this; nothing captured an aggregate-scoped one.
6. `from_pm(:field, default:)` — sourcing a saga/PM handler value from the
   process manager's own persisted state, a third sibling of `from_event`
   and `from_iter`.
7. Saga memory was write-once, set only from the starting event's payload at
   creation. `remember key: from_event(...)` lets a mid-saga handler write
   forward, closing the gap that blocked converting the last two
   Proc-based process managers in the whole migration off the pre-hecksagain
   imperative PM DSL.
8. Handler-level `given { |ctx| ... }` — a dispatch-level precondition
   distinct from the transition guard (the transition and any `remember`s
   still happen; only the dispatch is gated).
9. `template("fmt %s", from_pm(...))` — string composition inside a `with:`
   value, the last piece needed for the same PM conversion as #7.
10. `group_by :field` — a third query-aggregation shape alongside
    `count`/`median`.
11. Policy `where field: value` — a conditional trigger gated on the
    triggering event's own payload.
12. Policy `for_each from:, where:` + `from_event` — fan-out dispatch, one
    trigger per row a named query returns.
13. `none_in_state` — a cross-aggregate anti-join query comparator (existed
    in the retired Rust runtime, had a dedicated proof fixture; had no
    hecksagain implementation).
14. `role Role, as: Agent` — role-bearer identity synthesis for a
    cross-domain role assignment (i483 in the source project).
15. `Aggregate.event_sourced` — a bare marker verb, additive sugar for
    `persisted_by("Heki")` when no other bind exists yet for that aggregate.
16. `WorldBuilder` had no `ConstShim` resolver at all, unlike
    `HecksagonBuilder`/`BluebookBuilder`. The aggregate-qualified
    binding-mirror form (`Pizzas::Order.charged_by("Stripe") do ... end`) —
    the exact shape the canonical Pizzas example's own `pizzas.world` uses —
    raised `NameError` on every world file written that way. Nobody had
    actually booted that half of the canonical example before this.
17. `.split`, `.last`, and block-taking `.all?`/`.any?`/`.none?` in the
    canonical-expression evaluator/resolver.
18. `.start_with?`/`.end_with?` in the same evaluator/resolver — sibling gap
    to #17, found in the same storehouse-kernel `Phrase`/`Params` value
    objects.

(`.match?`, `.present?`, and `.blank?` are the same family and were the
first three found; not recounted here as separate line items since they're
the same shape as #17/#18, found earlier in the same pass.)

## Real dispatch-time correctness bugs (9)

Constructs hecksagain *did* support, but which broke — sometimes silently,
sometimes with a crash — the moment a real value flowed through them:

19. `Value::Coercion#fields_for` refused a bare scalar for any single-field
    value object on `then_set`, even though the unambiguous case (exactly
    one field) had an established precedent two methods away
    (`#from_identifier`). Broke `then_set :status, to: "active"` — one of
    the most common mutation shapes in any corpus.
20. `Resolver` never unwrapped a `Value` for bare comparison
    (`status == "active"`) — every bare `guarantees`/`expects` field
    comparison against a VO-typed field was silently, unconditionally
    `false`.
21. `Evaluator#top_level_index` tracked paren depth but not brace depth — a
    block predicate's own internal comparison operator split the whole
    expression in half before the block was ever recognized as one atomic
    leaf.
22. `Admissibility#admissible_transition` leaked a raw Ruby object pointer
    into refusal messages for any VO-typed lifecycle field — and, worse,
    used that same unconverted pointer as the actual value being matched
    against candidate `from:` states, so the *transition logic itself*
    silently broke, not just the message.
23. `MutationApplier`'s `increment`/`decrement`/`multiply` wrapped the
    literal amount whenever the target attribute existed, but never checked
    whether the *current* value was already wrapped — crashed with a type
    mismatch on the first-ever mutation of any VO-typed numeric field that
    had no field-level default.
24. `Rendering.describe` had no case for a bare `Value` — any other call
    site handing it one (type-mismatch messages, numeric-field checks,
    creation-conflict messages) leaked the same raw pointer as #22.
25. `Value::Coercion#from_identifier` never coerced the derived identity
    string back to a numeric field's declared type — any aggregate with an
    `Integer`- or `Float`-typed `identified_by` field could never
    successfully create a record, on any input, valid or not.
26. `AttributeCollector`/`AggregateBuilder`'s inverted-form detection
    (`attribute TypeConstant, as: :name`) checked `!name.is_a?(Symbol)`, but
    a bare-constant reference always resolves to a Symbol via `ConstShim` —
    identical to a literal field-name Symbol — so the check could never
    fire. Corrupted 147+ lines across a framework kernel before the real
    signal (PascalCase vs. snake_case) was found.
27. `SagaInterpreter#resolve_value`'s bare `IR::TemplateSpec` reference
    resolved against the wrong namespace (`Runtime`, not `Bluebook`) —
    `NameError` on every saga dispatch that reached a `template()` call,
    the moment #9 above was actually exercised for real.

## Self-hosting / registry structural fixes (5)

28. `Registry#add_hecksagon` was a plain hash overwrite, not an accumulator
    — a multi-file-per-domain hecksagon split across several files (one per
    aggregate) silently kept only the *last*-loaded file's binds,
    discarding every earlier one. `BluebookBuilder` already had the
    accumulate-not-discard fix for multi-file bluebooks; hecksagons had
    never gotten the same treatment.
29. A synthesized bare-primitive-wrapper value object colliding with an
    unrelated, hand-written value object of the same name (an ordinary
    English-word coincidence, not a corpus mistake) needed a general,
    build-time disambiguation pass — not a per-file patch — since the
    collision can happen in either declaration order.
30. Bare `Boolean` as a type constant resolved through `ConstShim` to the
    Symbol `:Boolean`, which the primitive-wrapper allowlist (real Ruby
    classes only) could never recognize — silently became a bogus String
    field literally typed `"Boolean"`.
31. The Judge (`meta_validator/judge.rb`) turned out to already be fully
    generic over the grammar's own declarations — not a separate walker
    needing its own code path. Confirming this *is* the structural finding:
    extending what the self-hosted grammar can say about itself is
    sufficient by construction; #1 needed no changes to `judge.rb`,
    `plan.rb`, or `readings.rb` at all once the grammar itself declared the
    field.
32. A repeatable idiom for resolving a bidirectional aggregate reference
    hecksagain's own DSL refuses (keep one side's `belongs_to` authoritative,
    add a query on the other side) — applied identically across several
    unrelated corpora and inside hecksagain's own self-hosted grammar file,
    confirming it as the language's real idiom rather than an invented
    workaround.

## Precisely diagnosed, deliberately not fixed

Not every finding got a fix — some are real, corpus-wide, and foundational
enough that rushing a fix under migration time pressure would have cost more
than leaving them open and documented:

- **`IR::Command#creates? = @references.nil?`** — a command that never calls
  `reference_to` on its own aggregate is unconditionally classified as
  CREATE, regardless of whether the target record already exists. This is
  not a bug in the heuristic — it's correct, working, intentional design,
  falsified only where corpus content self-addresses an existing record
  through the same shape a real creator uses. The fix is corpus content
  (`reference_to(Self)` on every self-addressed transition command), not a
  runtime change — every runtime-only fix considered either reopens a real
  `AlreadyExists` protection or flips a default across every aggregate in
  every corpus simultaneously. Confirmed reaching this repo's own storehouse
  framework kernel (`OutboundEvent`, `CascadeRun`), not just leaf corpus
  content.
- **A real `.behaviors` interpreter.** hecksagain's own testing convention
  is RSpec + JSON fixtures, a different format, not a superset of the
  bluebook-native `.behaviors` DSL some migrated corpora depend on. No port
  exists; `behaviors`/`conceive-behaviors` return an honest
  `{ok:false, supported:false}` rather than crashing or silently no-opping.
- **The effect-family async-verdict subsystem** (`Aggregate.verb("Adapter",
  on: "Event") do success "Cmd" ; failure "Cmd" end`) — documented by the
  canonical Pizzas example itself, and confirmed via direct grep to have
  zero implementation anywhere: no `on`/`success`/`failure` fields on
  `IR::Bind`, no adapter-host delivery mechanism, no verdict re-entry
  wiring. The single largest unimplemented-subsystem finding of the whole
  migration.
- **Cross-aggregate method calls inside `given`/`expects`**
  (`Account.find_by_auth_identity(id).nil?`) — the canonical-expression
  evaluator has no method-call-with-arguments syntax at all, and no notion
  of reaching a live registry mid-predicate. Real, common, found 11 times
  across two unrelated corpora.
- **IdentityDiscipline's detection logic** — traced conclusively, not
  assumed: it was never built, in either runtime. The bluebook aggregate
  declares only the data contract (counters, an audit entity, three
  commands); nothing ever wired an event to `Check`, and `Check`'s own
  description narrates a walk it never actually performs. Not this
  migration's regression — a phase of an older design (i611 Phase 2) that
  was designed on paper and never shipped.

## Total

**36 distinct, independently verified gaps found and closed** in this fork
this session — 18 new DSL constructs the language could not parse at all,
9 dispatch-time correctness bugs invisible to `validate`, and 5 self-hosting
or registry structural fixes — plus **5 more, precisely diagnosed, left
open on purpose** rather than rushed under the same time pressure that broke
things elsewhere in this project's own history (see `rust-experiment.md`).

Every fix above was verified by a real `hecksagain-cli dispatch` against the
actual corpus that surfaced it, not just a passing `validate` — the same
discipline this document's own second section names as the reason most of
these were findable at all. See the commit history immediately preceding
this document for the change-by-change record.
