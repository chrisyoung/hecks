# Bluebook Engineer Standard Operating Procedure

**Role:** take requirements, conduct interviews, implement bluebooks for users.
**Applies to:** any new chapter, and any change to an existing one.

The QA engineer's `qa/SOP.md` is the model for this document. Their governing
principle is *fix first, file second*. Mine is:

> **BOOT IT. A bluebook that has not been dispatched into is a guess.**

Everything below exists to get to a real dispatch sooner, and to make the
handover afterwards worth reading.

---

## Phase 1 — Intake (20 min)

Requirements arrive as prose from somebody who knows their domain and not this
language. Read all of it before modelling any of it.

1. **Read the requirement documents end to end.** Do not start at the first
   aggregate they name.
2. **Read the artefacts they are trying to replace.** If they have a markdown
   file, a spreadsheet, or a naming convention doing the job today, that file
   *is* the domain. `qa/FINDINGS.md` told me more about what the QA ledger
   needed than `qa/BLUEBOOK_REQUIREMENTS.md` did — including the three states
   the requirements had no word for.
3. **Write down their vocabulary, verbatim.** Their words go in the chapter.
   Where I depart from a word, that departure is a decision I owe them a
   reason for.
4. **List their explicit success criteria.** They are the acceptance test.

**Do not negotiate the requirements yet.** Half of what looks wrong at intake
turns out to be right, and the other half is easier to argue about once there
is something to point at.

---

## Phase 2 — Interview (30–60 min, or asynchronous)

The `/interview` skill and `bin/interview` exist for this and build the chapter
declaration by declaration. Use them when the user is present.

When the user is **not** present — an agent that left a document and went back
to work — the interview happens against the artefacts instead. The questions
are the same:

- What is the thing this chapter is actually *about*? (Everything else is
  scaffolding around it. For the QA ledger it was the **bug**, not the session.)
- Which facts outlive their session? Those are heads.
- Which facts are meaningless without a parent, and never pointed at? Entities.
- Which of their "statuses" are really **lifecycles**, and what are the edges
  nobody mentioned? The reverse edges — regressed, reopened, reverted — are
  almost never in a requirements document and almost always real.
- Which of their sets **grow**? A set fixed by design is `one_of`. A set the
  practice learns is a table, or plain text. Getting this backwards is the most
  common modelling error in a requirements document.
- What must be **impossible**? That is the sentence worth the most work.

Record what you could not ask and had to assume. It goes in the handover.

---

## Phase 3 — Shape (30 min, on paper)

Before writing DSL, settle the four decisions the language will not let you
change cheaply:

1. **Head or entity, per concept.** Decide by the mechanics first, taste second
   — see `MODELLING_HAZARDS.md` A4/A5. Anything holding a list or pointed at by
   a reference is a head, and no amount of taste overrides that.
2. **What is enforced vs surfaced.** Cross-aggregate rules are surfaced (C4)
   unless they can be a required `reference_to` (C5). Decide which, per rule,
   and say so in the chapter.
3. **Which counters exist.** Apply C3: an aggregate's own commands, or nothing.
4. **Every value object's name**, prefixed against B2.

Then count the aggregates. If the answer is more than the user asked for,
either drop one or be ready to defend it in a paragraph. If it is fewer,
be ready to defend that too — I removed a requested aggregate from the QA
ledger and it needed a full paragraph.

---

## Phase 4 — Implement (60–90 min)

Write the chapter. House style, which is not optional here — read
`lib/hecksagain/framework/bluebook/interview.bluebook` first if you have not:

- **Comments carry the reasoning, not the mechanics.** Nobody needs "this is
  the reference"; everybody needs "this is a head rather than an entity
  because a Ticket must point at it, and a reference reaches heads only."
- **Write out what was taken back.** A rejected policy with its reason is worth
  more than the four commands you kept. Every chapter in this corpus does this
  and it is the reason they survive contact with a later reader.
- **Cite evidence, not intuition.** "Measured, not feared" beats "this might
  break". If a hazard bit you, name the file and the failure.
- **A `description` on every query is what a reader sees in a tool.** Write it
  as a sentence about *why the list matters*, not what it filters.

Wire it: a `.hecksagon` naming the persistence bind and a `.world` naming where
it lives. `Memory` for a corpus member. For anything durable, prefer
`Postgres`: it is the only lineage-capable adapter, so a shape change refuses
the boot until somebody writes a translation edge. That is a real tax on a
chapter still in motion and it is usually the right one — the alternative is
choosing a store to dodge a discipline, which is what `Heki` was doing in the
QA ledger until it was moved.

---

## Phase 5 — Prove it (30–60 min) — THE GATE

**No chapter is handed back without a spec that boots it and dispatches into
it.** Building and sealing prove almost nothing: every hazard in group C and D
of `MODELLING_HAZARDS.md` builds cleanly.

The spec must:

1. **Boot for real**, with `Memory` rebound so it does not write to the durable
   store (`spec/quality_control_spec.rb` shows the pattern).
2. **Dispatch every command at least once**, including the creating one.
3. **Assert on query CONTENTS, never on "it did not raise".** D1 and D2 both
   return a wrong answer silently; only a content assertion catches them.
4. **Test the valid case, not only the refusals.** The `.strip` regression, D1
   and D2 are all valid inputs being refused or dropped.
5. **Assert the refusal CLASS and its WORDING** for every rule that matters —
   see F. The wording is the product.

Then run the whole suite, not just your file:

```bash
bundle exec rspec --order random
```

Record the count and the seed. **Put them in the commit message.**

```
Verified: bundle exec rspec --order random  (312 examples, 0 failures, seed 41022)
```

A number and a seed are checkable. "Tests pass" is not — and the QA engineer's
own broken commit is the worked example of why that distinction matters.

---

## Phase 6 — Hand back (20 min)

The user gets a written reply, not just a file. It covers, in this order:

1. **Anything I found broken on the way**, first, before my own work.
2. **What exists and where**, with the command to run its spec.
3. **Where I departed from the spec, and why** — a table of asked-for vs built,
   one row per departure. Every "no" needs its reason in the same line of
   sight.
4. **Their success criteria, ticked off one by one**, naming the actual verb.
5. **Answers to every question they asked**, including the ones where the
   answer is "this should not exist".
6. **What I need from them.**

`qa/MESSAGE_FROM_BLUEBOOK_ENGINEER.md` is the worked example.

---

## Phase 7 — Record what the language taught you (10 min)

Every chapter teaches something about the DSL. If it is not written down it
gets rediscovered by the next engineer at the same cost.

- A hazard → `modelling/MODELLING_HAZARDS.md`, with the evidence.
- A runtime bug → the QA ledger, through `qa/quality_control`, not a markdown
  file: `write_test` then `log`, and `Log` will refuse until you hand it the
  `demonstration` that proves the bug, which is the point. (The Ruby
  `Ledger` class this used to name is gone — it held a second way to do
  everything, including its own `gh` shell-out beside the `IssueTracker`
  port. The command line is the only door.)
- A session → `modelling/reports/YYYY-MM-DD.md`.

---

## Working alongside other agents

- **Isolated worktree, always.** `git worktree add -b <branch> /tmp/<name> <base>`.
  Branch from the branch the requester is on, not from `main`, or their
  artefacts will not be there.
- **Never edit a file on somebody else's active branch**, even to fix it.
  Hand the fix over with the evidence and let them apply it. `BUG#11` is the
  worked example: I had the fix, proved it, and did not apply it.
- **Deliver messages into their live checkout**, not only into the worktree,
  or they will not see them until a merge.
- Their documents move while you work. **Re-read them before handing back** —
  the QA ledger gained a `paused` state and bug-to-bug blocking because
  `qa/FINDINGS.md` changed mid-build.

---

## Checklist before handing back

- [ ] `modelling/MODELLING_HAZARDS.md` §G checklist passes
- [ ] A spec boots the chapter and dispatches every command
- [ ] Query assertions are on contents, not on absence of error
- [ ] Full suite green — count and seed recorded in the commit message
- [ ] Every departure from the requirements has a stated reason
- [ ] Every question the requester asked has an answer
- [ ] New hazards written down; new runtime bugs in the ledger, not in markdown
- [ ] Nothing edited on somebody else's branch
