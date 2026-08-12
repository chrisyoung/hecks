# Modelling Findings

Language and runtime gaps found while building bluebooks. Distinct from
`modelling/MODELLING_HAZARDS.md`, which is how to *avoid* them — this is the
register of what should be fixed.

**Bugs live in the ledger, not here.** Anything reproducible goes through
`Ledger#discover` / `#reproduce`; the reference below is the handle. This file
holds the modelling-side reasoning that does not belong in a bug record.

---

## Open

### `BUG#11` — a predicate using an unknown method breaks every dispatch
**Severity:** high · **Status:** paused, handed to the QA engineer

`!value.to_s.strip.empty?` builds, seals and boots. At dispatch,
`Expression::Resolver#lookup` reads `value.to_s.strip` as a three-segment
attribute path, indexes into a String, and raises `TypeError` — for *every*
input, valid ones included.

**The modelling point:** the failure is not that `.strip` is missing. It is
that an unknown method **silently degrades into a path lookup** instead of
being refused when the bluebook is declared. Every other malformed thing in
this language is refused at build. A predicate is the one place where a typo
survives to production and takes an aggregate with it.

**What would fix it properly:** the expression grammar knows its own operator
table (`lib/hecksagain/grammar/expression.bluebook`). A leaf segment that
matches no declared attribute *and* looks like a method call — trailing `?`, or
a name in a known-method denylist — could refuse at seal with "no `.strip` in
the predicate sublanguage; the vocabulary is …". That message would have saved
a day.

Workaround, and the right modelling answer regardless: anything textual is
`pattern:`, not a predicate.

---

### `BUG#12` — an array `in:` is stringified and can never match
**Severity:** high · **Status:** investigating

`where(status: { in: %w[a b] })` reaches the IR as `"[\"a\", \"b\"]"`. Silent;
the query returns `[]` forever.

**The modelling point:** `in:` is the natural way to express "any of these
lifecycle states", which is the single most common query a lifecycle-bearing
chapter wants. Every author will reach for the array form first. Either it
should work or it should be refused at seal — silently returning nothing is
the worst of the three options.

**Worth auditing:** any bluebook in this repository using an array `in:` has a
dead query and no test will say so unless it asserts on rows.

---

### `BUG#13` — an empty-string comparand is dropped
**Severity:** medium · **Status:** investigating · **Blocked by:** `BUG#12`

`where(f => { ne: "" })` becomes `ne: nil`, which every row satisfies.

**The modelling point:** "this optional field has been filled in" is a normal
thing to want to ask, and the empty string is the normal way to say "not
filled in". A sentinel word works and reads better, but it is a workaround
being chosen for a mechanical reason, which is exactly the kind of thing a
later reader mistakes for a modelling decision. Hence the comment in
`quality_control.bluebook`'s `BlockingBug`.

---

### The facade stops one level short — entity commands and queries have no door
**Severity:** low · **Status:** open, not filed as a bug (it is a gap, not a defect)

`Facade::Surface` makes aggregate work read as Ruby — `Bug.discover(...)`,
`bug.reproduce(...)`, `bug.status`. Two things fall outside it:

- an **entity command** (`Session.TestCase.Pass`), because `Surface` installs a
  module per aggregate and `Handle#define_verb_methods` walks `ir.commands`;
- a **query** (`Bug.Unfixed`), which has no door at all.

Both stay `runtime.dispatch` / `runtime.query` strings, and every spec in the
corpus carries the same two exceptions.

**The modelling point:** it pushes authors away from entities. An entity is
already the harder sell (it cannot be referenced, cannot hold a list); making
it the only shape whose commands read worse in a spec adds a reason to reach
for a head that has nothing to do with the domain. `Session::TestCase.pass(...)`
on a nested door, and `Bug.unfixed` as a door method per declared query, would
both follow from IR the surface already walks.

Recorded here rather than in the bug ledger because nothing is *wrong* — a
`Ledger` caller never sees it. It is a cost paid by whoever writes the spec.

---

## Accepted limitations — no fix wanted

These are refusals of the language, not bugs. Recorded so they are not
relitigated every chapter.

### A predicate cannot quantify over a list
No blocks, no `.any?`. Hold a counter and increment it in the appending
command. The cost is real (see below) and the alternative — putting an
interpreter for arbitrary Ruby inside a declared-data language — is worse.

### A counter cannot be moved by another aggregate's commands
Entity commands land on the entity; a foreign aggregate's commands land on it.
This is correct — it is aggregate boundaries doing their job — and it means any
requested "statistics" or "coverage" aggregate should be a query instead. It
came up on the very first engagement and will come up on every one.

### A `given` cannot read through a reference
A reference is an id at dispatch. The rule becomes a dotted-`where` query,
surfaced rather than enforced. Also correct: enforcing it would mean loading
the referenced record on every dispatch.

The exception worth knowing is that a **required `reference_to` is itself an
enforceable rule**, because the reference must resolve. That is how
"no ticket without a fix attempt" got enforced.

### A value object's name can collide with any aggregate name in the process
`Facade::Surface.install` puts every aggregate name on `Object`. Prefixing is
the discipline. A fix — scoping the facade per boot — would be a real change to
how the surface works and is not obviously worth it; the failure is loud once
you know the shape (`no ValueObject … named Domain:Aggregate:Other::Name`).

Filed here rather than as a bug because the *hazard* is the boot-order
dependence, not the constant installation, and that is a design trade this
codebase has already made deliberately.

---

## Fixed

*(nothing yet — this register opened 2026-08-11)*
