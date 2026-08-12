# Modelling Hazards

The traps in this DSL, each one hit for real. `qa/BUG_FINDING_METHODOLOGY.md`
is the QA engineer's equivalent: eight categories for attacking a running
system. This is the same idea aimed at the *language* — the places where a
bluebook builds, boots, seals, and is still wrong.

**Read this before writing a chapter, and again before believing one works.**

The hazards are grouped by when they bite. The dangerous ones are the last
group: they neither raise nor refuse.

---

## A. Refused when the bluebook builds

The cheap ones. You find out immediately.

### A1. The inline `one_of(...)` shorthand collides inside `value_object`

`one_of(...)` called inside a `value_object do ... end` block resolves to the
*value object's own* `one_of`, not the enclosing builder's, and fails on arity.
Always declare the long way:

```ruby
value_object "Severity" do
  attribute :value, String
  one_of do
    member value: "high"
    member value: "medium"
    member value: "low"
  end
end
```

### A2. `pattern:` admits far less regex than Ruby does

`Bluebook::PatternSubset` refuses `\d \D \w \W \s \S`, POSIX classes
(`[:digit:]`), lookahead, lookbehind, backreferences, atomic groups and
possessive quantifiers. What remains: explicit ranges, alternation,
quantifiers, anchors, groups. `^`/`$` are line anchors.

This is deliberate — a pattern is declared data and must read identically in
every engine. Spell the range you mean:

```ruby
attribute :value, String, pattern: '[^ \t\n\r]'          # not \S
attribute :value, String, pattern: '^[0-9a-fA-F]{7,40}$'  # not \h
```

### A3. A `where` path must land on a scalar

`where(blocked_by: ...)` where `blocked_by` is a value object is refused at
seal. Use the dotted field path to the scalar leaf:

```ruby
where(:"blocked_by.value" => { ne: "none" })
```

### A4. An entity cannot hold a `list_of`

`Coercion.hydrate_entity_list` reaches for `aggregate.entities`, which an
entity does not have. **Anything that needs to hold a list is a head.** This
is often the argument that settles entity-vs-aggregate before taste does.

### A5. A `reference_to` reaches heads only

`entity_builder` declares no `reference_to` at all. **Anything that must be
pointed at is a head.** Corollary: an entity is cited by *number*, and nothing
checks that the number names a real one.

---

## B. Refused at boot

### B1. `identified_by` needs the extraction port

`identified_by { reference.value }` recovers its own predicate's source through
the extraction port. A boot that loads `persistence.port` and the memory
adapter but forgets `extraction.port` + `prism.adapter` fails on the *first
aggregate*, with a message about predicates that reads like a runtime problem:

```
no adapter implements the extraction port — nothing can recover a predicate's source
```

### B2. A value object named after any aggregate, anywhere, is a landmine

`Facade::Surface.install` installs **every aggregate name as a top-level
constant on `Object`**. Once any other domain has booted in the process, a bare
`Statement` in your chapter resolves to `Banking::Statement` — a real Ruby
constant — instead of reaching `const_missing` and being read as a name.

The failure mode is the bad one: **green alone, red in the suite**, depending
on boot order.

Prefix every value object with its own aggregate's noun: `BugTitle`,
`DefectSite`, `RemedyChange`, `TicketRepository`. Words to never use bare:
`Title`, `Site`, `Cause`, `Change`, `Statement`, `Repository`, `Resolution`,
`Order`, `Account`, `Session`, `Identity`.

---

## C. The predicate sublanguage is much smaller than Ruby

**This is the most expensive hazard in the file.**

The whole vocabulary of `given`, `invariant` and `ensures` is
`lib/hecksagain/grammar/expression.bluebook`:

| available | not available |
|---|---|
| `+`, `%` | any other arithmetic |
| `.positive?` `.negative?` `.zero?` | `.strip` `.downcase` `.include?` `.start_with?` … |
| `.empty?` | `.blank?` `.present?` |
| `.to_s` | `.to_i` `.to_sym` |
| `.size` (and `.length`, read as `.size`) | — |
| `==` `!=` `<` `<=` `>` `>=` | — |
| `!` `\|\|` `&&` | blocks of any kind |
| dotted attribute paths | `.any?` `.all?` `.map` `.find` |
| `old.` inside `ensures` | — |

### C1. An unknown method is NOT refused — it is read as an attribute path

`!value.to_s.strip.empty?` does not fail to build and does not fail to boot.
`Expression::Resolver#lookup` treats `value.to_s.strip` as a three-segment
path, walks into a String, and raises **from inside the runtime, at dispatch**:

```
TypeError: no implicit conversion of Symbol into Integer
  lib/hecksagain/bluebook/expression/resolver.rb:215
```

Every dispatch through that value object dies — **valid inputs included**. This
shipped into `examples/pizzas/bluebook/pizzas.bluebook` (commit `63750a3`) and
took `spec/pizzas_spec.rb` to 19-of-27 failing. Recorded as `BUG#11`.

**Anything textual belongs in `pattern:`, not in a predicate.** `pattern:` is
checked during coercion, before any predicate runs.

### C2. There is no quantifier — you cannot look inside a list

`test_cases.any? { |t| t.outcome == "open" }` is not expressible; there are no
blocks at all. If a rule needs to know something about a list, **hold the
number** as an attribute and increment it in the command that appends:

```ruby
then_set :test_cases, append: { ... }
then_set :tested,     increment: { value: 1 }
ensures("testing never loses a test case") { tested.value == old.tested.value + 1 }
```

### C3. A counter is only honest if the aggregate's own commands move it

The other half of C2, and the one that kills most requested fields. An entity
command's mutations land on **the entity**, never on the head that holds it.
A different aggregate's commands land on **that aggregate**. So:

- `Session#tested` is fine — `Session.Test` increments it.
- `Session#bugs_found` is not — `Bug.Discover` cannot reach it.

Anything in the second category is a **query**, not a field. Same reasoning
kills any "coverage" or "statistics" aggregate: every field on it is a count of
somebody else's rows, and nothing in the language can maintain it.

### C4. A `given` cannot read through a reference

A reference is an **id at dispatch time**, not the record it points at.
`bug.status` resolves to nothing inside a predicate. Only a `where` clause hops:

```ruby
query "RestingOnUnreproduced" do
  where(status: "drafted")
  where(:"bug.status" => "found")     # this works
end
```

So a cross-aggregate rule is **surfaced, not enforced** — which is the honest
outcome anyway. The list is what a human closes.

### C5. The one cross-aggregate rule you CAN enforce: a required `reference_to`

A reference must resolve to a real record at dispatch. So "you may not do X
without having done Y" becomes: make X's command require `reference_to Y`.

`Ticket.Draft` requires `reference_to Remedy` — a ticket that cannot name a fix
attempt cannot be drafted at all. This is the strongest form a rule takes in
this language, and it is only available if Y is a head (see A5).

---

## D. Silent — nothing raises, the answer is just wrong

The dangerous group. Assert on **contents**, never on "it didn't raise".

### D1. An array `in:` can never match — `BUG#12`

```ruby
where(status: { in: %w[found reproduced] })
```

The array reaches the IR already `to_s`'d: `"[\"found\", \"reproduced\"]"`.
`Ports::Query::InMemory#members` then comma-splits *that string*. The query
returns `[]` forever, with no error.

**Workaround:** the comma-string form, which `members` splits correctly.

```ruby
where(status: { in: "found,reproduced" })
```

**Audit any existing bluebook using an array `in:`** — its query is dead and
nothing in the suite will say so unless a test asserts on the rows.

### D2. `ne: ""` matches everything — `BUG#13`

The empty string is dropped between the DSL and the `WhereClause`, which comes
out holding `value=nil`. The clause then asks `!= nil`, which every row
satisfies — the exact opposite of the question.

**Workaround:** a real sentinel word, plus a `default:` so unset records carry
it.

```ruby
value_object "BlockingBug" do
  attribute :value, String, default: "none"
end
# where(:"blocked_by.value" => { ne: "none" })
```

This reads better anyway: `"none"` is a fact somebody asserted, where `""` is
indistinguishable from a field nobody filled in.

### D3. `contains` means two different things

Real element membership for a `list_of` field; plain substring for anything
else. Known and documented in `in_memory.rb`, still surprising.

---

## E0. Write specs through the facade, not through dispatch strings

`Runtime::Loader.bind_runtime` installs a door per aggregate. Use it — a spec
full of `runtime.dispatch("Domain::Agg.Verb", id: ..., ...)` spends half its
assertions proving the spec passed the right id to the right verb, which is a
fact about the spec.

```ruby
runtime = Hecksagain::Runtime::Loader.bind_runtime(dispatcher)   # not the bare dispatcher

bug = QualityControl::Bug.discover(session_id: session.id, ...)  # creating verb → module method
bug.reproduce(demonstration: { value: "rspec ..." })             # every other verb → on the handle
bug.status                                                        # lifecycle state
bug.commit.to_h                                                   # attribute reader
```

`Handle#run` builds the identity from `identity_heads` and its own state, so a
non-creating verb never takes an id — composite identities included. Verbs
return the handle, so they chain.

**A value object is always `{ field: value }`, never a bare scalar** — even
when it has one field. `bug.pause(reason: "x")` raises `TypeMismatch: reason is
a BugReason — pass its fields as an object`. `remedy.reason.to_h` is the
round-trip.

### The facade's edges — measured, not assumed

An aggregate door carries exactly: `all`, `commands`, `count`, `events`,
`find`, `fqn`, `ir`, `port`, `repository`, and one method per **creating**
verb. That is the whole list. So:

- **Entity commands have no door.** `Surface` installs one module per
  *aggregate*, and `Handle#define_verb_methods` walks `ir.commands`, which does
  not include an entity's. `session.pass(...)` does not exist —
  `runtime.dispatch("Domain::Aggregate.Entity.Command", id:, sequence:, ...)`.
- **Queries have no door.** `QualityControl::Bug.unfixed` does not exist —
  `runtime.query("Domain::Aggregate.QueryName", **args)`.

Wrap both in one helper each at the top of the spec and the rest of the file
reads as ordinary Ruby.

### A command and an attribute cannot share a name

The door defines an attribute reader and a verb method on the same handle, so
`attribute :plan` plus `command "Plan"` both want `target.plan` and whichever
is defined last silently wins. Rename one. (`Target.Plan` became `Target.Rank`
for exactly this.) Nothing warns.

---

## E. Verb and row shapes worth writing down

Not hazards exactly — just things that cost an hour to rediscover.

| | |
|---|---|
| aggregate command | `Domain::Aggregate.Command` |
| entity command | `Domain::Aggregate.Entity.Command` |
| entity query | `Domain::Aggregate.Entity.Query` |
| port operation | `Domain::Aggregate.Port.Operation` (ports resolve **before** entities) |
| read model | `Domain.ReadModel` (no `::`) |

**An entity query row is stamped with `Naming.reference_key(aggregate)` —
which is `:session`, not `:session_id`.** A reference *attribute* on a head is
`:session_id`. The two naming paths differ and both are right.

An entity's identity is minted by `MutationApplier#entity_element` as
`size + 1` when the append omits it. Do **not** pass `sequence` from the
caller; do pass it to every later entity command.

Boot a tool with `install_facade: false` and dispatch by string, or you leak a
global constant per aggregate into the process.

---

## F. Refusal classes — assert on the right one

Getting this wrong makes a test pass for the wrong reason.

| class | raised when |
|---|---|
| `AbsentArgument` | a required argument was not supplied at all |
| `TypeMismatch` | `pattern:` or a type constraint refused the value |
| `InvariantViolation` | a value object's `invariant` refused |
| `LifecycleRefused` | the command is not admissible from the current state |
| `GivenNotMet` | a command's `given` predicate refused |
| `NotFound` | a `reference_to` names no record |
| `AlreadyExists` | a creating command collided on identity |

`LifecycleRefused` is the one people expect to be `GivenNotMet`. Its wording is
excellent and worth asserting on — it is what a calling agent reads:

```
Investigate refused — status is "found", and Investigate moves it only from "reproduced"
```

Prefer a lifecycle edge over a `given` wherever the machine can carry the rule:
it costs no predicate, it cannot be forgotten, and the refusal explains itself.

Prefer a **required argument** over a `given` reading a nullable field: the
argument is refused during coercion and a caller cannot skip it.

---

## G. The checklist

Before handing a chapter back:

- [ ] Every value object prefixed against the aggregate-constant collision (B2)
- [ ] No predicate uses a method outside the table in C — grep for `.strip`,
      `.downcase`, `.include?`, `.blank?`, `.any?`
- [ ] Anything textual is `pattern:`, and the pattern passes `PatternSubset` (A2)
- [ ] No array `in:` anywhere (D1); no `ne: ""` anywhere (D2)
- [ ] Every counter is moved only by its own aggregate's commands (C3)
- [ ] Every cross-aggregate rule is either a required `reference_to` (C5) or a
      dotted-`where` query that says in its `description` that it is surfaced,
      not enforced (C4)
- [ ] **Booted for real**, not just built — a spec that dispatches every
      command and asserts on query *contents*
- [ ] The valid case is tested, not only the refusals. Every silent hazard
      above and the `.strip` regression are valid inputs being refused or
      dropped, and no test that only checks refusals would catch any of them.
