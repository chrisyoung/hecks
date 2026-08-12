# Bluebook Engineering

**Who this is.** The bluebook building engineer. I take requirements, conduct
interviews, and implement bluebooks for the other agents and humans working in
this repository.

**Finding me.** Sessions are named after their working directory, so I will not
be called "bluebook engineer" in `ListAgents` — look for a session working in a
`hecksagain` worktree and check what it has open. Better: leave a document.
Drop a `MESSAGE_TO_BLUEBOOK_ENGINEER.md` in this directory and I will read it
the way I read `qa/MESSAGE_TO_QA_BLUEBOOK_AGENT.md`. That is how the QA
engineer reached me and it worked.

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
| wiring | `qa/bluebook/quality_control.{hecksagon,world}` — Heki, `qa/data/` |
| spec | `spec/quality_control_spec.rb` — 24 examples |
| library | `lib/hecksagain/quality_control/ledger.rb` |
| tools | `lib/hecksagain/development_mcp/` + `bin/hecksagain_development_mcp` |
| handover | `qa/MESSAGE_FROM_BLUEBOOK_ENGINEER.md` |

Four aggregates — `Session` (with a `TestCase` entity), `Bug`, `Remedy`,
`Ticket`. Twenty-seven `qc_*` MCP tools, one per step of `qa/SOP.md`.

---

## The development MCP

`hecksagain_development_mcp` — this repository's own tools, spoken as MCP.
Registered in `.mcp.json`; started by the editor.

```bash
# by hand, to check it
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | bin/hecksagain_development_mcp
```

Named for the repository rather than for quality control, because QA is the
first practice to get tools here and will not be the last. Every tool it serves
today is prefixed `qc_`; a second practice adds a second prefix and no new
server.

**If you are doing QA work, use these instead of editing markdown.** Start with
`qc_status`. The workflow is enforced by the model, so the tools will refuse
you in the language's own words — `qc_investigate` on a bug nobody reproduced
answers:

```
REFUSED — Investigate refused — status is "found", and Investigate moves it
only from "reproduced"
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
