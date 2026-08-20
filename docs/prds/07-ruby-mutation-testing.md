# PRD 07 — Automated mutation testing of hecksagain's own Ruby source

**Status:** In progress. Step 1 (evaluate `mutant`) done, with a real
finding; a first real mutation run completed against one method
(`ArgumentGate#refuse_unknown_arguments`) with concrete, triaged results.
See "Findings" below. Widening to the rest of `command_interpreter.rb` +
siblings is the remaining work.

## The problem

Two different things both go by "mutation" in this codebase, and it's worth
being precise about which one this PRD is:

- The **DSL's own** `append`/`remove`/`multiply`/`clamp` "mutations" — a
  declared, first-class language construct, extensively covered by this
  session's own `mutations_match_recompute` property. Not this PRD.
- **Mutation testing as a QA technique** — deliberately mutating
  hecksagain's own Ruby *source code* (flip a comparison operator, delete a
  guard clause, change a boundary) and checking whether the test suite
  actually catches it. This is what this PRD builds.

The only trace of this second sense anywhere in the repo is a comment in
`lib/hecksagain/runtime/command_interpreter.rb`:

> "Mutation testing found this the other way round: the only two
> declarations in banking whose removal changed observable dispatch
> behaviour were both `identified_by`."

That describes a real, one-off, **hand-done** exercise — removing bluebook
*declarations* one at a time and watching for behavior change, closer to
`Bluebook::MetaValidator`'s own domain than to a Ruby-source mutant run —
not a repeatable tool. No automated version of either sense exists.

## Why this is worth doing, and why it's sequenced late

Mutation testing is the classic technique for finding **weak assertions** —
tests that pass regardless of whether the code they claim to verify is
correct (an `expect(result).not_to be_nil` where the real bug would still
produce a non-nil, just wrong, result). Given how much of this session's own
work was property-based (recomputing an *independent* expectation rather
than asserting against production's own answer), there's a real chance this
codebase's assertion discipline is already unusually strong — but "probably
strong" isn't "measured," and this is the technique that measures it.

It's sequenced after the cheaper PRDs in this set on purpose: it's the
highest infrastructure cost here (tooling setup, and a mutation run is
inherently `O(mutants × suite runtime)` — slow even on a fast suite), and
the other PRDs are more likely to find something concrete faster. Do this
once there's already momentum from earlier wins, not as the opening move.

## Approach

1. Evaluate `mutant` (the standard Ruby mutation-testing gem) against this
   codebase's real constraints — it has known friction with metaprogrammed/
   DSL-heavy code, and this codebase's own `Bluebook`/`Builder` layer is
   exactly that. Confirm it's usable before committing to it; if `mutant`
   itself struggles to even generate sensible mutants against the DSL
   builder layer, that's a real finding worth reporting rather than forcing
   through.
2. **Scope narrowly first** — `lib/hecksagain/runtime/command_interpreter.rb`
   and its own `mutation_applier.rb`/`argument_gate.rb` siblings (the
   dispatch pipeline, already the most heavily property-tested code in the
   runtime, so a good place to find out whether "heavily tested" and
   "well-asserted" are actually the same thing here). Do not attempt the
   whole gem on the first pass.
3. Every surviving mutant (a mutation the suite didn't catch) is a real
   finding — either a genuinely untested branch, or a weak assertion.
   Triage each: fix the test, or confirm the mutant is behaviorally
   equivalent (some are — a mutation that produces provably identical
   behavior isn't a gap) and document why, the same "measured, not
   assumed" discipline this whole set of PRDs already holds to.

## Acceptance criteria

- [ ] A real mutation run completes against `command_interpreter.rb` +
      immediate siblings, with a concrete mutation-kill rate reported (not
      "seems fine" — an actual number).
- [ ] Every surviving mutant is triaged: fixed, or documented as
      behaviorally equivalent with a one-line reason.
- [ ] A decision recorded on whether to widen scope beyond this first pass
      (this PRD's own acceptance doesn't require widening — that's a
      follow-up call based on what the first pass actually finds).

## Findings (evaluation pass, worktree-mutation-testing)

**`mutant` generates mutations against this code fine.** No DSL-parsing
trouble against the dispatch pipeline — 2640 mutations across the full
`CommandInterpreter*` scope, no crashes, no unparseable constructs. Step
1's stated risk (mutant struggling against metaprogrammed/DSL-heavy code)
did not materialize here — but a *different*, more fundamental problem
did:

**mutant-rspec's default test selection is structurally blind to this
codebase's spec style.** It correlates a subject to tests by parsing the
first word of each example's `full_description` as a Ruby constant/method
expression (`mutant-rspec`'s `Integration::Rspec#parse_metadata`). This
codebase's *unit-style* specs (~20+ files, e.g. `spec/router_spec.rb`,
`spec/freezer_spec.rb`) use `RSpec.describe SomeClass` and correlate fine.
Its *behavior/property-style* specs — the majority, and where the dispatch
pipeline is actually exercised — are prose-described
(`RSpec.describe "the rules a command obeys"`), so mutant found only
11/1950 tests selected (0.31 tests/subject avg) against the full
`CommandInterpreter*` scope. A `TracePoint`-based coverage probe across
the real suite confirmed this is a false negative, not a real gap: **109
of ~150 top-level describe blocks genuinely execute code in
`command_interpreter.rb`/`argument_gate.rb`/`mutation_applier.rb`** —
this dispatch pipeline really is heavily tested, exactly as this PRD's own
premise assumed; mutant's naming heuristic simply can't see it. Given how
broad that real coverage is, a targeted `mutant_expression`-tagging fix
would end up selecting nearly the whole suite for nearly every subject
anyway, so the honest fix is a `mutant` hook (`mutant/full_suite_selector.rb`)
that forces every
mutation to run against the real full suite instead of the broken
correlation — the O(mutants × suite runtime) cost this PRD already
expected, not a shortcut around it.

Building that hook surfaced one more real, general-Ruby finding, unrelated
to hecksagain's own code: `Mutant::Hooks.load_pathname` evals hook files
inside a class method's (`Mutant::Hooks.load_pathname`, a singleton
method) binding — under a singleton-method binding, plain `module Foo;
class Bar; def method; end; end; end` reopening syntax resolves against
the wrong lexical scope and silently creates a disconnected shadow class
instead of reopening the real one (reproduced with a minimal repro
completely outside mutant — a general `binding.eval` + singleton-method
quirk). `SomeClass.class_eval do ... end` sidesteps it.

**First real run:** `ArgumentGate#refuse_unknown_arguments` (116
mutations, full suite — 1950 tests — run per mutation, 6 parallel jobs,
~46s wall time). Result: **103/116 killed, 13 alive (88.79% coverage)**.
Triage of all 13:

- **1 infra flake, not a finding** — one mutation (`75ed8`) crashed its
  test-runner fork outright (nonzero exit from something in the Rust
  codegen parity path, not a clean rspec failure) rather than being killed
  or surviving cleanly. Needs its own look before the next run, separate
  from test-suite quality.
- **4 real gaps, same missing test case** — removing `.sort`
  (`f7918`) and changing `.join(", ")`'s separator (`72a9a`, `f5fe2`,
  `215cd`) on the `unknown` list all survive. The source's own comment
  says this ordering is "contract — pinned byte-for-byte by the corpus,"
  but no test calls `refuse_unknown_arguments` with **two or more**
  simultaneous unknown arguments — with only ever one, sort order and
  join separator are unobservable. One new test (a command called with
  two+ undeclared arguments) would kill all four.
- **4 real gaps, same root cause** — dropping (`9510d`), renaming
  (`14c70`), or corrupting (`478fa` → `nil`, `a24f3` → the command object)
  the `declared:` interpolation all survive. Verified against
  `RefusalWording.render` (`lib/hecksagain/runtime/refusal_wording.rb:115`):
  it `gsub`s only the placeholders it's given values for and never
  validates the rest, so a dropped/wrong `declared:` leaves the raised
  message either missing that segment or showing the wrong text
  (`"...it takes {declared}"` literally, or `"...it takes "`, or the
  command's own `#to_s`) — not caught because no test asserts the
  *rendered message text* of an `unknown_args` refusal that has a
  non-empty declared-attributes list, only that `UnknownArgument` is
  raised. Directly contradicts the "pinned byte-for-byte" comment for
  this specific refusal.
- **4 likely-equivalent mutations** — `.map(&:to_sym)` → `.each(&:to_sym)`
  or dropped entirely, on both `known` (`5b9f8`, `a5d1c`) and
  `args.keys` (`642df`, `4dd41`). Spot-checked, not exhaustively proven:
  `Facade::JsonDoor#deep_symbolize` (`lib/hecksagain/facade/json_door.rb:107`)
  symbolizes every payload key before it reaches dispatch, and
  `Attribute#name` is an IR-declared field, so both sides of this
  subtraction are already symbols on every real call path — the
  `.to_sym` coercions read as defensive dead code, not exploitable gaps.
  Worth a firmer check (does *anything* reach `refuse_unknown_arguments`
  with unsymbolized keys?) before spending a fix on them.

Net: of 13 survivors, **8 are real, actionable findings** (1 new test
closes 4 of them; the `declared:` corruption is arguably the more
interesting one — a genuine hole in the "wording is pinned" claim), 4 are
probably-equivalent dead code, and 1 is a harness flake to chase down
separately. This is a good sign for the codebase's assertion discipline —
88.79% single-method coverage with real, explainable, mostly-narrow gaps —
but it's one method out of ~35 subjects across the three files; nowhere
near enough to call the wider acceptance criteria met yet.

## Non-goals

- Mutation-testing the entire gem in one pass — start narrow, expand only
  if the first pass proves the tooling works cleanly against this
  codebase's style.
- Automating the *other* sense of "mutation testing" (removing bluebook
  declarations one at a time) as a repeatable tool — that's a genuinely
  different, smaller idea (closer to `bin/model_check`'s own territory)
  worth its own, separate PRD if it turns out to matter; conflating the two
  here would blur what this PRD is actually measuring.
