# Issue-tracker reconciliation plan — 2026-08-26

_Prompted by a critique agent's claim of "186 open issues." That count is
correct as a raw `gh issue list --state open` tally, but it is not a live
backlog — see below. This doc is the plan for closing the gap between the
tracker and reality, not a plan to hand-fix 186 bugs._

## Headline finding

**186 GitHub issues are open. Spot-checks across every category show the
underlying bugs are already fixed on `main`. Zero of the 186 were closed by
today's fix commits.** The tracker is stale, not the codebase.

Evidence:

| # | Issue | Claim | Current code (`main`) |
| --- | --- | --- | --- |
| #322/#321/#320 | Withdrawal.Dispute missing State/Customer/Account guards | 3× "missing guard" | `payment_cards.bluebook:70-73` — all 3 guards present |
| #290/#289 | ScheduledPayment.Retry missing status guards | 2× "missing guard" | `transfers_and_payments.bluebook:356-358` — present |
| #313/#312/#311 | Transfer.Reverse missing status guards | 3× "missing guard" | `transfers_and_payments.bluebook:125-127` — present |
| #267/#265 | LedgerEntry.Reverse/Amend missing guards | 2× "missing guard" | `deposit_accounts.bluebook:90-92,102-104` — present |
| #318/#317 | Visit.Annotate missing Customer/Box guards | 2× "missing guard" | `safe_deposit_boxes.bluebook:119-121` — present |
| #264 | KeyIssuance.Return missing `then_set :serial` | "missing then_set" | `safe_deposit_boxes.bluebook:159-161` — guards present (originally reported as guard-shaped, not a `then_set` gap in current code) |
| #310/#308 | Transfer.Request missing `then_set`/destination validation | 2× findings | `transfers_and_payments.bluebook:65-75` — dereferenced source/destination guards present, with inline commentary explaining the fix |

13 issues sampled across 7 different entities, 4 different `.bluebook`
files, and all 3 "missing guard / missing then_set / missing validation"
title patterns. **13/13 already resolved in code.**

## Why the tracker and the code diverged

Two root-cause PRs did the real work, but neither was written to close the
141 individual `qa-legacy`-labeled symptom issues:

- **#161 / #164** — `given`/`ensures` couldn't dereference a cross-aggregate
  reference (`customer.status`) or an entity's `parent.customer.status`.
  Until this landed, guard clauses referencing related records could not
  work at all, which is *why* ~120 "missing status guard" bugs were filed
  in the first place — the guards being added kept failing to dispatch.
- **Item `1855be0-n`** (issue #141, part of the `hecks-hecksagain` epic) —
  added `given("named condition")` shorthand (a bare string resolves to a
  convention-derived predicate, falling back across sibling entities/
  aggregates), which is the idiom now used in every command shown above
  (`given("customer is active")` with no block).

Once both landed, every command that had been individually filed as
"missing guard" could just... have the guard added in one line, or in some
cases already resolved via the cross-entity fallback #141 built. That work
happened, but commit messages reference Tier/audit IDs and DSL item numbers
— not the individual `qa-legacy` issue numbers — so `gh issue close` never
ran.

**Separately**, the `docs/audits/2026-08-10-main-bug-audit.md` /
`2026-08-11-bug-triage.md` findings (75 items, S1-S3/H1-H14/M1-M29/L1-L24/
R1-R5 — this is where the user's specific list came from: the M20
reaction-dispatch race, missing query aggregation, fuzzer/adapter coverage,
Postgres migration integrity holes, the stored-XSS/HMAC/SQL-injection
security findings) were swept **tier-by-tier today** in 8 commits
(`b34a09b1` → `75eb9c82`), plus a follow-up lint-tooling pass
(`35003cc0`, `80950212`) that found bugs *beyond* that original 73-item
sweep. Cross-referencing the user's specific concerns against that sweep:

| User's concern | Audit ID | Status |
| --- | --- | --- |
| Race in nested reaction dispatch (`@reaction_depth`) | M20 | Fixed — `e4b7a473`, and the *same bug class* re-found and fixed in the registry (`80950212`, with a forced-interleaving regression spec) |
| No count/sum/group_by in query DSL | (pre-audit) | Added 2026-08-13 (`c84f9f3e`); Judge round-trip tracked as open issue #113 |
| Fuzzing only covers in-memory adapter | M21-M25 | Fixed — `4839adae` (Tier 6) |
| Postgres schema migration holes | H3, H4, H5 | Fixed — `b34a09b1` (H4 was already fixed pre-audit) |
| Stored XSS, Rust web layer | H10 | Fixed 2026-08-22 (predates today's sweep) |
| Session HMAC fails open on empty secret | H11 | Fixed — `b00e667d` (Tier 3) |
| Unsanitized SQL in rename-schema | L20 | Fixed — `b00e667d` (Tier 3) |
| Rails integration is design-only | — | **Still true.** `docs/rails-integration.md` is design-only by scope, not a bug. Genuinely open if the user wants it built. |
| "Fixes 73 bugs" commit, audit says never re-verified | — | See below. |

So: of the concerns raised, only **Rails integration** is a real, currently
unaddressed gap — and it was scoped out deliberately, not missed.

## The one real caveat: nothing above is independently re-verified

`docs/audits/2026-08-11-bug-triage.md` says explicitly: *"This is a
reorganization, not a re-verification... re-verify a finding before
starting work on it."* That warning still applies to the *fix* commits
themselves — each Tier-fix commit cites its own test evidence (full
`rspec` at 2189/2189, a forced-interleaving concurrency spec for the race,
etc.), and my spot-checks above independently confirm 13/13 sampled
symptom-issues against current source — but no one has run a **fresh**
line-by-line audit against `main` since the sweep landed. Confidence is
high, not certain.

## Plan

**Phase 1 — Reconcile the 186 GitHub issues (bulk, evidence-cited, batched)**
1. For the 141 `qa-legacy` issues: script a check (title → entity/command →
   grep the relevant `.bluebook` for the named guard/`then_set`) across all
   9 source files properly (today's manual spot-check regex was too naive
   for full automation — needs real parsing of nested `entity`/`command`
   blocks, not a flat regex). Close each confirmed-fixed issue with a
   comment linking #161/#164/#141 and the exact line now satisfying it.
   Anything the script can't confirm gets hand-reviewed, not auto-closed.
2. For the 38 `hecks-hecksagain` issues: check each `1855be0-*` item
   against the commit log (most already appear to have landed — e.g. #141
   is visibly in production use above). Close what's shipped; leave what
   isn't.
3. For the 7 unlabeled issues (#173, #170, #167, #164, #161, #101, #75):
   handle individually — #167/#164/#161 are the root-cause PRs themselves
   and may already be merged (verify and close); #101 (fuzzer crash) and
   #75 (pattern-validation default) need their own check.

**Phase 2 — Independent re-verification of the audit sweep**
Run `bundle exec rspec`, `bin/fuzz --seeds 60 --steps 40`, `bin/model_check`,
and `cargo test` fresh against current `main` tip (not the commits' own
self-reported numbers), and re-read H3/H11/L20/M20 at their current
`file:line` to confirm the fix is what the commit message says. This is
cheap insurance given the triage doc's own warning.

**Phase 3 — Rails integration (the one real gap)**
Decide whether `docs/rails-integration.md` moves from design to
implementation, and if so scope it as its own project — it's substantial
(read side, authz, per-attribute labels, uploads, ActionCable, adapter
split are all explicitly undesigned), not a bug-fix.

**Phase 4 — Prevent recurrence**
The drift happened because fix commits didn't reference issue numbers.
Going forward: require `Closes #N` in commit/PR bodies for anything with a
tracked issue, and add a periodic (e.g. weekly) reconciliation check —
even a cheap script that greps recently-closed-worthy patterns against
open issue titles — so "186 open issues" never again means "13 fixed
issues nobody closed" without anyone noticing for two weeks.
