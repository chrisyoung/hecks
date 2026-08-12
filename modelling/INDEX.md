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
| spec | `spec/quality_control_spec.rb` — 40 examples |
| cli | `qa/quality_control` — projected, not written |
| adapters | `qa/adapters/` — github, ci, rspec_runner, fuzzer, toolchain |
| handover | `qa/MESSAGE_FROM_BLUEBOOK_ENGINEER.md` |

Five aggregates — `Target` (the rotation), `Sweep` (one pass, with a `Check`
entity), `Bug`, `Ticket`, `Clearance`. Lineage-bearing: era 1 is minted on the first boot against
an empty database, and every shape change after that needs a translation edge
(`bin/scaffold_translation`, then `bin/translation_audit`) before the ledger
will open again.

```bash
createdb hecks_quality_control   # once; the first boot mints era 1
```

---

## Using the ledger

`qa/quality_control` is its command line — minted by `bin/project_cli` beside
the domain it drives, and projected from the chapter: every verb, every
question, every argument typed, and every refusal, computed at the moment it
prints. Nothing about QualityControl is written into it. Add a command to the
bluebook and it appears; the file is twenty-five lines and boots `__dir__`.

```bash
qa/quality_control                       # every verb and question
qa/quality_control log --help            # what it wants, and how it refuses
qa/quality_control ask queue             # read; changes nothing
```

It runs from anywhere, which is the point — the QA agent stands wherever the
bug is, not in `qa/`.

A typical pass, in the order the chapter enforces:

```bash
qa/quality_control target.claim id=QC held_by.value=agent-one
qa/quality_control open target_id=QC reference.value=SW-9 engineer.value=agent-one
qa/quality_control check id=SW-9 subject.value="Banking::Account.Freeze" \
                         expectation.value="a frozen account refuses a second freeze"
qa/quality_control surprised id=SW-9 sequence.value=1 observation.value="the second freeze was accepted"
qa/quality_control write_test id=SW-9 scope.value=spec/qa_bugs_spec.rb source.value="…"
qa/quality_control log sweep_id=SW-9 reference.value=BUG#1 sequence.value=1 \
                       title.value="…" demonstration.value=spec/qa_bugs_spec.rb \
                       symptom.value="…" expectation.value="…" submitter.value=agent-one
qa/quality_control conclude id=SW-9 notes.value="…"
```

**THERE IS NO RUBY API BESIDE THIS, AND THAT IS DELIBERATE.** A
`Hecksagain::QualityControl::Ledger` class used to live in `lib/` holding a
booted runtime and a second way to do everything — including its own
`gh` shell-out, competing with the `IssueTracker` port. It was deleted: two
paths to filing an issue is one more than a ledger whose whole claim is that
nothing reaches the outside world unrecorded can survive. Everything the
practice can do, it does through the doors below.

Ruby callers use the facade the chapter installs — `QualityControl::Bug.log(...)`,
`bug.investigate(...)` — which is what `spec/quality_control_spec.rb` does.

## The outside world, through ports

The agent shells out to nothing. Every tool it needs is an `asks` on one of
five ports, so a run becomes a record rather than terminal scrollback:

| port | verbs |
|---|---|
| `Testing` | `run_specs`, `write_test`, `smoke_test`, `bisect` |
| `Fuzzing` | `fuzz`, `model_check` |
| `Toolchain` | `translation_audit`, `refresh_projections`, `structure`, `read_docs`, `run_script` |
| `CI` | `clearance.run` |
| `IssueTracker` | `raise` → `submit` → `poll` |

`answers` versus `refuses` means "did the call work", NOT "was the news
good". A fuzz run that finds a counterexample ANSWERED — that is the tool
working. The one exception is `CI`, where a red suite IS a refusal, because
that port asks a different question: not "what happens when you run this" but
"will you vouch for this commit".


**The workflow is enforced by the model, so it will refuse you in the
language's own words.** Verifying a fix nobody made answers:

```
Verify refused — status is "logged", and Verify moves it only from "fixed"
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
