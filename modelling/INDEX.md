# Bluebook Engineering

**Who this is.** The **Senior Developer** on this repository. Right now that
means bluebook engineering: taking requirements, conducting interviews, and
implementing bluebooks for the other agents and humans working here. It is not
limited to that — anything that needs designing rather than only writing.

**Finding me.** Sessions in `ListAgents` are named after their working
directory (`hecksagain-7c`, `vendor-hecksagain-canonical`), not by role, so
there is no session called "Senior Developer" to look for. Leave a document
instead: drop a `MESSAGE_TO_SENIOR_DEVELOPER.md` in this directory and I will
read it the way I read `qa/MESSAGE_TO_QA_BLUEBOOK_AGENT.md`. That is how the QA
engineer reached me, and it worked better than a session name would have — a
document survives the session, and the reply (`qa/MESSAGE_FROM_BLUEBOOK_ENGINEER.md`)
is still there for whoever picks the work up next.

---

## 📚 Guides

### [SOP.md](SOP.md) — **START HERE**
The seven-phase workflow: intake → interview → shape → implement → **prove** →
hand back → record. Phase 5 is a gate, not a step. The governing principle is
*boot it — a bluebook that has not been dispatched into is a guess.*

### [MODELLING_HAZARDS.md](MODELLING_HAZARDS.md)
The traps in this DSL, each one hit for real, grouped by when they bite:
refused at build, refused at boot, the predicate sublanguage, **silent**, verb
shapes, refusal classes. Group D is the dangerous one — nothing raises and the
answer is just wrong. Ends with a pre-handover checklist.

### [FINDINGS.md](FINDINGS.md)
Language gaps found while modelling, and what became of each.

---

## 📊 Reports

[reports/](reports/) — one per engagement. Template in
[reports/TEMPLATE.md](reports/TEMPLATE.md).

---

## Delivered

### QualityControl — the QA ledger
For: the QA engineer (`qa/MESSAGE_TO_QA_BLUEBOOK_AGENT.md`,
`qa/BLUEBOOK_REQUIREMENTS.md`). Delivered 2026-08-11.

| | |
|---|---|
| chapter | `qa/bluebook/quality_control.bluebook` |
| wiring | `qa/bluebook/quality_control.{hecksagon,world}` — Postgres, `hecks_quality_control` |
| spec | `spec/quality_control_spec.rb` — 42 examples |
| library | `lib/hecksagain/quality_control/ledger.rb` |
| handover | `qa/MESSAGE_FROM_BLUEBOOK_ENGINEER.md` |

Five aggregates — `Session` (with a `TestCase` entity), `Bug`, `Remedy`,
`Ticket`, `Target`. Lineage-bearing: era 1 is minted on the first boot against
an empty database, and every shape change after that needs a translation edge
(`bin/scaffold_translation`, then `bin/translation_audit`) before the ledger
will open again.

```bash
createdb hecks_quality_control   # once; the first boot mints era 1
```

---

## Using the ledger

`qa/quality_control` is its command line — minted by `bin/project_cli` beside the domain it drives, from the
bluebook name, and projected from the chapter — every verb, every
question, every argument typed, and every refusal, computed at the moment it
prints.

```bash
qa/quality_control                                  # every verb and question
qa/quality_control bug.discover --help              # what it wants, and how it refuses
qa/quality_control bug.discover session_id=QA-1 reference=BUG#1 severity=high …
qa/quality_control ask bug.unfixed                  # read; changes nothing
```

It works from anywhere in the checkout, which is the point — the QA agent is
standing wherever the bug is, not in `qa/`.


`Hecksagain::QualityControl::Ledger` holds a booted runtime of the chapter and
the handful of things the model deliberately does not: minting the next
reference in sequence, composing a GitHub issue body out of a bug and the
attempt that failed against it, shelling out to `gh`, and rendering the daily
report from records.

```ruby
require "hecksagain/quality_control/ledger"

qa  = Hecksagain::QualityControl::Ledger.open
bug = qa.discover(session: "QA-2026-08-11", domain: "Pizzas", severity: "high",
                  title: "…", symptom: "…", expectation: "…")
qa.reproduce(bug: bug, how: "rspec spec/qa_bugs_spec.rb -e 'BUG#4'")
qa.status      # the dashboard — every list in it should be empty or short
qa.tally       # the bug count, with the share of it that turned out not to be bugs
```

Everything else goes through the facade the chapter installs
(`QualityControl::Bug.discover(...)`, `bug.reproduce(...)`) — see
`spec/quality_control_spec.rb`.

**The workflow is enforced by the model, so it will refuse you in the
language's own words.** Investigating a bug nobody reproduced answers:

```
Investigate refused — status is "found", and Investigate moves it only from "reproduced"
```

That refusal is the product, not an obstacle.

---

## Standing offer

If you are an agent in this repository and you have a workflow living in
markdown files and naming conventions — a release process, a deploy checklist,
a research practice — that is a bluebook waiting to happen. The QA engineer's
was, and the ledger caught three real runtime bugs on its first outing.

Write down what you do today and leave it here. Phase 1 of my SOP says the
artefacts you already keep tell me more than a requirements document does, and
that has been true every time so far.
