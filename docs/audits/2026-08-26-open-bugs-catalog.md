# Open bugs catalog — 2026-08-26

_Every issue confirmed still open after the 2026-08-26 reconciliation pass
(see [`2026-08-26-issue-tracker-reconciliation-plan.md`](2026-08-26-issue-tracker-reconciliation-plan.md)
for how the original 186 got here). Each entry below was **investigated
live** against current `main` — not left open by default, not guess-closed
either. Every one has an evidence comment on its own GitHub issue._

**Status: all batches complete.** Every one of the original 186 open
issues has now been investigated live against current `main`.

---

## Group 1 — Deliberate design, not a gap (4 issues)

The literal fix requested would have been a *regression* against
intentional behavior. Investigated by hand this session; a naive fix to
each broke real specs or a documented guide example before being reverted.

| # | Ask | Why it stays open |
| --- | --- | --- |
| [#308](https://github.com/chrisyoung/hecks/issues/308) | `Transfer.Request` destination-account/customer validation | Breaks the documented saga-compensation example (`docs/implemented/guides/policies-and-process-managers.md`, "Compensation — the refused leg") — the destination is deliberately left unchecked at intake so the reversal path stays reachable |
| [#305](https://github.com/chrisyoung/hecks/issues/305) | `Transfer.Reject` destination validation | Would block legitimately rejecting a transfer whose destination has since gone bad — backwards for a refuse-before-anything-moved command |
| [#301](https://github.com/chrisyoung/hecks/issues/301) | `Transfer.Debited` destination validation | Destination is deliberately checked downstream, at `Settle`/`Credited`, matching `Reverse`'s own source-only guards |
| [#278](https://github.com/chrisyoung/hecks/issues/278) | `SafeDepositBox.Rent` customer-status guard | `:customer` is a plain value object, not `reference_to`-typed — the shared guard mechanism has nothing to dereference. Needs a real DSL change, not a one-liner (confirmed: a naive add broke ~20 specs) |

**Recommended next step**: product/design call on each — none need more investigation, they need a decision on whether the current behavior is correct (looks like yes, for #308/#305/#301) or whether #278 is worth the DSL work.

---

## Group 2 — `redirects_native`: one settled question, three open issues (3 issues)

| # | Angle |
| --- | --- |
| [#155](https://github.com/chrisyoung/hecks/issues/155) | self-hosted grammar round-trip |
| [#142](https://github.com/chrisyoung/hecks/issues/142) | DSL builder |
| [#122](https://github.com/chrisyoung/hecks/issues/122) | corpus exercise |

All three trace to the same fact: `redirects_native` doesn't exist anywhere
in `lib/` or `examples/` today, and neither does its motivating consumer
(a `GovernedDoor`/`Tools::FileTool` MCP-redirect concept named in the
original issues) — `docs/hecks-survey-what-we-wish-we-had.md:249` documents
the word as deliberately retired.

**Recommended next step**: close all three as a group once the retirement
decision is confirmed current, rather than leaving three duplicate open
issues around one already-settled question.

---

## Group 3 — Vendored/pre-rename code with no consumer in this repo (4 issues)

| # | What |
| --- | --- |
| [#133](https://github.com/chrisyoung/hecks/issues/133) | `AppendLog` adapter |
| [#132](https://github.com/chrisyoung/hecks/issues/132) | `DiskBuffer` + `screenshot_buffer` port |
| [#131](https://github.com/chrisyoung/hecks/issues/131) | `DreamImage` + `dream_image` port |
| [#130](https://github.com/chrisyoung/hecks/issues/130) | `Stripe` + payment port |

Source commits for all four self-label as vendored, pre-`Hecksagain`→`Hecks`
rename code. None has a DSL verb that exists in the current grammar
(`buffered_by`, `imaged_by`, `charged_by` are all absent), and none has a
consumer anywhere in this repo's own corpus — one's consumer (`dream.hecksagon`)
belongs to the sibling `hecks_playground` repo, not this one.

**Recommended next step**: confirm these are out of scope for this repo
specifically (not just "not yet built") before deciding whether to close
or actually port them.

---

## Group 4 — Genuinely absent features (not round-trip bugs) (5 issues)

The issue is titled as if something already-built is silently broken; in
each case the underlying capability doesn't exist yet at all, so there's
nothing to "fix" — only to build.

| # | Asked-for fix | What's actually missing |
| --- | --- | --- |
| [#121](https://github.com/chrisyoung/hecks/issues/121) | Handler `remembers`/`guard_count` round-trip | No `remember` DSL word, no runtime write path into saga memory, no leg-level guard mechanism at all — a real 4-part feature |
| [#116](https://github.com/chrisyoung/hecks/issues/116) | Handler guards survive MetaValidator round-trip | Entirely downstream of #121 — no guard mechanism exists yet to fail to round-trip |
| [#153](https://github.com/chrisyoung/hecks/issues/153) | Entity queries auto-scope to their named parent | The premise doesn't match how `reference_to` works anywhere else in the DSL (it's just an argument declaration, never implicit scoping); the one real corpus example with this shape (chess's `Piece.OnBoard`) deliberately does the opposite |
| [#144](https://github.com/chrisyoung/hecks/issues/144) | `HecksagonBuilder` success/failure async-verdict stub | Needs a real async-verdict subsystem, not a mechanical fix |
| [#145](https://github.com/chrisyoung/hecks/issues/145) | driving-adapter grammar + raw-adapter fix | Genuinely future work per this repo's own survey doc (`docs/hecks-survey-what-we-wish-we-had.md`), substantial undesigned scope |

**Recommended next step**: each needs its own scoping/design pass before
implementation — same treatment `docs/rails-integration.md` already got.

---

## Group 5 — Partially done / superseded by a sibling construct (1 issue)

| # | Ask |
| --- | --- |
| [#113](https://github.com/chrisyoung/hecks/issues/113) | `Query` gets `count`/`median`/`group_by`; `Policy` gets `where`/`with`/`for_each` |

Split verdict: Policy's half is fully implemented and live in production
(`examples/banking/bluebook/deposit_accounts.bluebook:504`'s
`Account.OpenForCustomer`, 6 passing specs). Query's half is genuinely
missing on `Query` itself — but the identical capability (the same three
words) already exists, fully tested (25 passing specs), on the sibling
`ReadModel` construct.

**Recommended next step**: a scoping call — is this superseded by
`ReadModel` (close it), or does `Query` genuinely need its own aggregation
mechanism alongside it (build it)?

---

## Group 6 — Needs its own investigation (4 issues)

| # | What |
| --- | --- |
| [#136](https://github.com/chrisyoung/hecks/issues/136) | item 1855be0-g catch-all stubs + `one_of`/`identified_by` fixes |
| [#141](https://github.com/chrisyoung/hecks/issues/141) | `CommandBuilder#given` default description + named-condition guards |
| [#139](https://github.com/chrisyoung/hecks/issues/139) | `BluebookBuilder#category`, free-form second classification axis |
| [#112](https://github.com/chrisyoung/hecks/issues/112) | `IR.render_value` spells an `IR::TemplateSpec` instead of raising |

- #136: the one real bug inside it is already fixed differently/better than proposed; the rest contradicts current deliberate design.
- #141: the useful part it proposed (named-condition `given("...")` shorthand) is already live and used throughout the banking corpus; the remaining specific asks in this issue have no corpus need and the issue's own text admits "no real semantics."
- #139: no corpus need yet; would require grammar registration + a golden-fixture regen with nothing real to verify it against.
- #112: the described architecture (`IR::TemplateSpec`, a `template()` construct) doesn't exist anywhere in current `Hecks::IR` — the issue predates a redesign.

---

## Group 7 — Documented, deliberate design (runtime/validation batch) (5 issues)

The last batch investigated (18 `qa-legacy` issues, the highest bug-density
one by design — runtime crashes and validation-enforcement claims). 13 of
18 turned out already fixed or fixed in this pass (see the fixed-bugs
tally in the reconciliation plan doc); these 5 are deliberate design,
each with a citation to the doc/spec that documents it:

| # | Ask | Why it stays open |
| --- | --- | --- |
| [#195](https://github.com/chrisyoung/hecks/issues/195) | `ATMCard.Issue` should reject zero daily fee | Negative is already rejected by an existing invariant; zero is intentionally allowed (a documented example) |
| [#191](https://github.com/chrisyoung/hecks/issues/191) | `Account.Credit` should check `daily_limit` | Documented, deliberate design — `daily_limit` applies elsewhere, not to `Credit` (`docs/implemented/guides/commands.md`) |
| [#190](https://github.com/chrisyoung/hecks/issues/190) | `CustomerStanding` should enforce a `one_of` | Deliberately free-form today — passing specs rely on arbitrary strings |
| [#185](https://github.com/chrisyoung/hecks/issues/185) | `Pizzas.Order.Purchase` should refuse underpayment | Would contradict the documented "external fact" design (`docs/implemented/guides/wiring.md`) |
| [#181](https://github.com/chrisyoung/hecks/issues/181) | Bundle of 3 structural IR sub-claims | All 3 confirmed working-as-designed; left open pending human confirmation on the bundled issue rather than unilaterally closed |

**Recommended next step**: same as Group 1 — a product/design call on each, not more investigation.

---

## Summary table

| Group | Count | Common thread |
| --- | --- | --- |
| 1 — Deliberate design (transfers/vault) | 4 | Literal fix = regression |
| 2 — `redirects_native` trio | 3 | One settled question, three tickets |
| 3 — Vendored, no consumer | 4 | Pre-rename code, nothing uses it here |
| 4 — Genuinely absent features | 5 | Real feature work, not a bug |
| 5 — Superseded by `ReadModel` | 1 | Scoping call needed |
| 6 — Needs its own look | 4 | Mixed |
| 7 — Deliberate design (runtime/validation) | 5 | Same shape as Group 1 |
| **Total confirmed open** | **26** | — |

All 186 original issues accounted for: 160 closed (real fixes landed
across this reconciliation plus this session's own work, and issues
already resolved by prior unrelated work, verified live rather than
trusted — see the individual PRs for exact per-issue evidence), 26 remain
open, every one with a documented reason on its own GitHub issue.
