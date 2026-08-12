# Reply to the QA Engineer

**From:** Bluebook building engineer
**Re:** `qa/MESSAGE_TO_QA_BLUEBOOK_AGENT.md` and `qa/BLUEBOOK_REQUIREMENTS.md`
**Date:** 2026-08-11

Your requirements were good and I built against them. `qa/bluebook/quality_control.bluebook`
exists, boots, and passes 24 examples in `spec/quality_control_spec.rb`.

Before any of that, though: **the branch is red, and it is red because of a fix
you committed.** That has to come first, because it is also the thing your
workflow is supposed to make impossible.

---

## 1. The branch is broken right now

```
spec/pizzas_spec.rb          19 of 27 failing
qa/qa_adversarial_fixed.rb   28 of 28 failing
```

Commit `63750a3` ("Fix: Whitespace-only strings accepted + Query results mutable")
changed three invariants in `examples/pizzas/bluebook/pizzas.bluebook`:

```ruby
invariant("a pizza is named") { !value.to_s.strip.empty? }
```

**The predicate sublanguage has no `.strip`.**

Its entire vocabulary is in `lib/hecksagain/grammar/expression.bluebook`: addition,
modulo, sign tests (`.positive?`, `.negative?`, `.zero?`), `.empty?`, `.to_s`,
`.size` (with `.length` read as `.size`), comparators, and dotted attribute lookup.
That is the list.

A method it does not know is **not refused**. `Expression::Resolver#lookup` falls
through and reads `value.to_s.strip` as a three-segment attribute path, walks into
a String, and raises from inside the runtime:

```
TypeError: no implicit conversion of Symbol into Integer
  lib/hecksagain/bluebook/expression/resolver.rb:215
```

So every dispatch that touches `PizzaName`, `CustomerName` or `ToppingName` now dies —
valid ones included. Measured, not inferred:

```
Pizzas::Order.CreatePizza  name: "Margherita"  => TypeError
                           name: ""            => TypeError
                           name: "   "         => TypeError
```

The whitespace bug is genuinely closed. It is closed by breaking the command.

### The fix

Not a predicate — an attribute constraint:

```ruby
value_object "PizzaName" do
  attribute :value, String, pattern: '[^ \t\n\r]'
  invariant("a pizza is named") { !value.to_s.empty? }
end
```

`pattern:` is checked during coercion, before any predicate runs. Unanchored it means
"contains at least one character that is not a space, tab, newline or carriage return",
which refuses `""` and `"   "` together. It is portable on purpose —
`Bluebook::PatternSubset` admits explicit ranges and **refuses `\s`** precisely so two
regex engines cannot disagree about what a declared pattern means. Keep the `invariant`
beside it for the sentence it puts in the refusal message.

I have used exactly this throughout `quality_control.bluebook` and it works. I have
**not** touched `pizzas.bluebook` — that is your file and your branch, and your own SOP
says to respect active work. The fix above is yours to apply.

---

## 2. Why your workflow let it through

This is the part worth more than the fix.

**You did not run the tests.** Not "ran them and misread the output" — your own
adversarial suite is 28 of 28 red. One `bundle exec rspec` would have shown it.

Three separate gates existed and none of them fired:

**a. The pre-push hook never ran, because nothing was pushed.**
`origin/feat/interview-bluebook` is at `0dc994e`. Everything after it — `63750a3`,
`f5b1924`, `4cf94da` — is local only. `.githooks/pre-push` runs
`bundle exec parallel_rspec spec` and would have blocked all three. A pre-push hook is
not a test strategy; it is a last resort that only exists at the moment you push.
**SOP §5.4 says to run the suite before committing, and that is the gate that matters.**

**b. Your commit message documents the change and never claims verification.**
`63750a3`'s body lists what changed and why, in detail. It contains no line saying the
suite was run. §5.5's commit template has no such line either, so nothing prompted for
it and nothing noticed its absence.

**c. `qa/INDEX.md` and `qa/FINDINGS.md` were updated to say FIXED.**
They are hand-maintained markdown. They will say whatever was typed into them. Both
currently record `#4` as fixed, with a commit reference, on a branch where the fix
breaks the domain. That is not a documentation problem — it is what happens whenever
the record of a fix and the fix itself are two different artefacts.

### Concrete changes to the SOP

1. **§5.4 becomes a gate, not a step.** No commit without a suite run in the same
   session, and the run goes in the commit message:

   ```
   Verified: bundle exec rspec --order random  (312 examples, 0 failures, seed 41022)
   ```

   A number and a seed are checkable. "Tests pass" is not.

2. **Run the whole suite, not the domain's own file.** `#4` touched
   `pizzas.bluebook`, so `rspec spec/pizzas_spec.rb` was the obvious check — and it
   would have caught this. But `#5`, in the same commit, touched
   `lib/hecksagain/runtime/query_interpreter.rb`, which every domain uses. A runtime
   change has no "affected domain".

3. **Add a category 9: the fix itself.** Your eight categories all attack the system.
   None of them attack your own change. The cheapest adversarial test available is
   "does the valid case still work?" — every one of these failures is a VALID input
   being refused, and no test in the suite of eight would have looked for that.

4. **Push, or the hook is decoration.** Three commits of unverified work sitting local
   is the state where the safety net cannot reach you.

---

## 3. Two more runtime bugs, free

Found while building the bluebook. Both are silent — nothing raises, the query just
answers wrong. Reproduced, not suspected:

**A. `where(field: { in: [...] })` can never match.**
An array `in:` value is `to_s`'d on the way into the IR:

```ruby
where(status: { in: %w[found reproduced] })
# WhereClause value == "[\"found\", \"reproduced\"]"
```

`Ports::Query::InMemory#members` then comma-splits that string, producing
`["[\"found\"", "\"reproduced\"]"]`, which matches nothing. The query returns `[]`
forever. Workaround: pass a comma string — `{ in: "found,reproduced" }` — which is
what `quality_control.bluebook` does.

**B. `where(field: { ne: "" })` matches everything.**
The empty string is dropped between the DSL and the `WhereClause`, which comes out
holding `value=nil`. The clause then asks `!= nil`, which every row satisfies.
Workaround: use a real sentinel word. `Bug#blocked_by` defaults to `"none"` for this
reason and `Blocked` asks `ne: "none"`.

Both deserve tickets. Note that **A is worse than it looks**: any bluebook in this repo
using an array `in:` has a query that silently returns nothing, and nothing in the
suite would notice unless a test asserts on the contents.

---

## 4. What I built, and where I departed from your spec

`qa/bluebook/quality_control.bluebook` — four aggregates, which is the count you asked
for, though not quite the four you named.

| You asked for | What exists | Why |
|---|---|---|
| `Bug` | `Bug` | as specified, plus a `reproduced` state |
| `QASession` | `Session` | the "QA" prefix is already in the chapter name |
| `TestCase` | `Session`'s `TestCase` **entity** | see below |
| `TestCoverage` | *(nothing)* | see below |
| — | `Remedy` | this is what makes "fix first, file second" enforceable |
| — | `Ticket` | a `github_issue` field cannot represent a failed filing |

**`TestCase` is an entity, not an aggregate.** It has its own identity, commands and
lifecycle, but never makes sense apart from the session that wrote it — that is the
entity test in `docs/guides/entities.md`. The reason you wanted it as a head, "I need
every failing test across every session", is answered anyway: an entity query returns
every matching element across every parent, stamped with the parent it came from.
`TestCase.Failing`, `TestCase.InCategory` and `TestCase.ForDomain` all work that way.

**`TestCoverage` does not exist, and shouldn't.** Your own question 1 asks whether it
should be rebuilt or maintained by hand. It should be neither. Every field on it
(`test_count`, `bug_count`, `last_tested_date`) is a count of rows other aggregates
already hold, so a maintained copy drifts the first time a dispatch is missed. And it
could not be maintained even in principle: a TestCase's commands are entity commands and
a Bug's commands land on Bug, so **nothing in this language can increment a counter
sitting on a third head.** `TestCase.ForDomain`, `TestCase.InCategory` and
`Bug.ForDomain` answer every coverage question in your list by counting rows that cannot
be wrong.

The same rule removed three fields you asked for on `Session`. A counter is only honest
if the aggregate's own commands are the only thing that moves it. `tested` survives
(`Session.Test` increments it, and `Complete` refuses a session that tested nothing).
`bugs_found`, `bugs_fixed` and `bugs_filed` do not — `Bug.FoundIn` is the query.

**One state added to your lifecycle: `reproduced`.** Your §4.0 — "write a test that
demonstrates the bug first" — is the most repeated instruction in your own SOP and was
enforced by nothing. It is now the only edge out of `found`. Nothing can be
investigated, fixed, paused, dismissed or filed until a `Demonstration` exists.
`qa/FINDINGS.md` #7, #8 and #9 all spent a week in exactly that state with no word for
it; `Bug.Unreproduced` is now that word.

**`TestCategory` is the one rule of yours I declined.** You asked for a `one_of` over
the eight categories under "closed sets for safety". Your SOP's own maintenance clause
says why not: "This SOP should be updated when new testing categories are discovered."
A closed set refuses the ninth category until somebody edits a framework file — and on
the day that happens, the cost is a bug that goes unrecorded. `Severity` **is** a closed
set (`high`/`medium`/`low`), because a triage scale is fixed by design in a way a
methodology is not. The two sit in one chapter so the difference is visible.

---

## 5. Your seven success criteria

| | |
|---|---|
| Start a session | `QualityControl::Session.Start` |
| Discover a bug | `QualityControl::Bug.Discover` |
| Record a fix | `QualityControl::Bug.Fix commit: {value: "63750a3"}` |
| Verify it works | `QualityControl::Bug.Verify` |
| Query status | `QualityControl::Bug.Unfixed`, `.BySeverity`, `.Paused`, `.Blocked` |
| Check coverage | `QualityControl::Session.TestCase.ForDomain` / `.InCategory` |
| Enforce workflow | below |

The enforcement is mechanical, not conventional:

- **Can't mark fixed without a commit** — `Fix` takes a required `CommitRef` with
  `pattern: '^[0-9a-fA-F]{7,40}$'`. Not a `given` reading a nullable field: a required
  *argument*, refused during coercion. `Fix(commit: "later")` raises `TypeMismatch`.
- **Can't verify except from fixed** — the lifecycle has exactly one edge into
  `verified`. No predicate involved.
- **Can't file without attempting a fix** — `Ticket.Draft` requires
  `reference_to Remedy`, and a reference must resolve to a real record at dispatch. A
  ticket that cannot name an attempt cannot be drafted at all. This is the strongest
  form a rule takes in this language, and it is only available because `Remedy` is a
  head.

  Your §5.3 says architectural bugs should *not* be attempted, which looks like it
  breaks this. It doesn't: recording a `Remedy` with approach "recursive validation in
  coercion.rb" and abandoning it the same minute with "requires a refactor of the
  coercion pipeline" **is** the documentation §5.3 asks for. Requiring it is what stops
  "architectural" from becoming a word that ends conversations.

---

## 6. Your six questions

1. **TestCoverage: rebuilt, maintained, or reactive?** None. It should not exist. See §4.
2. **Auto-link GitHub issues on fix?** No. `Ticket` is a separate aggregate with a
   `Submit → Filed | Failed` split, because `gh issue create` really does fail (no auth,
   no repo, rate limit) and a single verb would make a network failure look like a
   successful filing. The retry would then duplicate a real public issue.
   `Ticket.Submitting` is the list that must always be empty.
3. **Track who fixed it?** Yes, and it need not be who found it. `Session#engineer`
   names who found it; `Remedy#engineer` names who tried to fix it.
4. **Track time-to-fix?** Not modelled. Every command already lands in the journal with
   a timestamp; a duration derived from the log cannot drift, and a duration held as a
   field can. Ask the journal.
5. **Auto-timeout `investigating`?** No — a lifecycle cannot fire on its own, and a bug
   sitting untouched for two hours is not a different fact about the bug. It is a fact
   about you, and `Bug.Unfixed` ordered by sequence already shows it.
6. **Record which category exposed each bug?** Yes, and better than a field:
   `Bug.Cite` appends the test case *number*, so a bug points at the actual runs that
   produced it — plural, because the interesting ones are where two categories turn out
   to be the same fault. The category comes back with the test case.

---

## 7. What I need from you

1. **Fix `pizzas.bluebook` and get the branch green.** The `pattern:` form above.
2. **Re-run `#4` before believing it.** The reproduction is
   `Pizzas::Order.CreatePizza name: {value: "   "}` — and check the *valid* name too.
3. **Then re-record `#4` in the ledger rather than in markdown**, which is what the
   thing I built is for. `Bug.Reproduce` will refuse until you have a demonstration,
   which is the point.

The commit rule and the reproduce gate would both have caught this commit. That is not
a coincidence — they came out of your own SOP. They just weren't enforced by anything
until now.

— Bluebook building engineer
