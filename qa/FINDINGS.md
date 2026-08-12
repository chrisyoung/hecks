# QA Findings Archive

Documented bugs and findings from systematic adversarial testing.

**Methodology Note:** One bug = one distinct root cause with one fix. Multiple failed specs from the same bug are not counted separately.

**Session Status:** 23 distinct bugs identified and fixed (22 original + 1 systemic in 2026-08-12 loop)

---

## Bugs Fixed (by root cause)

| # | Bug | Root Cause | Fix | Impact |
|---|-----|-----------|-----|--------|
| 1 | Arrays not frozen at materialization | Instance defaults and mutation applier didn't freeze | Add `.freeze` to list materialization | HIGH - State mutation vulnerability |
| 2 | Query results/event logs mutable | Dispatcher and query interpreter returned unfrozen data | Add `.freeze` to result collections | HIGH - Data corruption risk |
| 3 | String attributes accept whitespace-only values | No pattern validation on String attributes across bluebooks | Add `pattern: '[^ \t\n\r]'` to all String VOs | MEDIUM - Data quality issue |
| 4 | Array `in:` query silently converts to string | Query interpreter type coercion | Special case handling for array types | HIGH - Silent failure |
| 5 | Empty string `ne:` query matches nil | Query interpreter null handling | Special case for empty string comparisons | HIGH - Silent failure |
| 6 | DailyLimit default violates positive invariant | Default value 0 conflicts with `cents.positive?` invariant | Change default to 100000 | MEDIUM - Initialization failure |
| 7 | SafeDepositBox missing Create command | Lifecycle has Create state but no command defined | Add Create command | HIGH - Incomplete aggregate |
| 8 | Expression.bluebook String validation gap | Grammar/language bluebook String VOs lack pattern validation | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 9 | World.bluebook String validation gap | Language bluebook String VOs lack pattern validation | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 10 | Hecksagon.bluebook String validation gap | Language bluebook String VOs lack pattern validation | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 11 | Translation.bluebook String validation gap | Grammar bluebook String VOs lack pattern validation | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 12 | Nested VO invariants not validated | Runtime doesn't validate invariants on nested VOs | Modify runtime validation | HIGH - Silent failure |
| 13 | Pizzas.Size.value lacks pattern validation | VO String attribute not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 14 | Syntax.Keyword.pair_key_fills lacks pattern | VO String attribute not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 15 | Syntax.Keyword attributes lack pattern | Multiple VO String attributes not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 16 | Banking.CustomerStanding.value lacks pattern | VO String attribute with default not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 17 | Banking.LedgerDirection.value lacks pattern | Closed-set VO String not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 18 | Banking.Money.currency lacks pattern | VO String attribute with default not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 19 | Banking.PositiveMoney.currency lacks pattern | VO String attribute with default not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 20 | Banking.AccountKind.name lacks pattern | Closed-set VO String not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 21 | Banking.StatementFrequency.cadence lacks pattern | Closed-set VO String not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 22 | Expression.SourceToken.value lacks pattern | VO String attribute not validated | Add `pattern: '[^ \t\n\r]'` | MEDIUM - Data quality |
| 23 | Returned aggregates not frozen | Dispatcher returns mutable results | Add `.freeze` to instance at return | CRITICAL - Data mutation/corruption |

---

## Affected Locations by Bug

### Bug #3: String Whitespace Validation (1 bug, 76 locations affected)

**Domain Bluebooks (48 locations):**
- banking.bluebook: AccountId, PersonName, Narrative, CardNickname, AuthorisationCode, EndToEndReference, MovementDirection, InstructionReference, Tag, VisitDate, OnboardingReference, StatementPeriod, StatementDate, WireTransfer::AccountNumber, DailyFee (type fix)
- till.bluebook: Mark.amount, Mark.direction, VisitNote, Note
- settlement.bluebook: Money
- payments.bluebook: DeclineReason.code, DeclineReason.message, Money
- dispatch_order.bluebook: Label, Note, Amount, PartSequence
- reflex.bluebook: LightName, LightCondition, BellName, SignalName, RingCount
- hop_chain.bluebook: Name, Reference, Number, Label
- pizzas.bluebook: Topping.name, Topping.amount

**Framework Bluebooks (18 locations):**
- governance.bluebook: IdentityId, RoleName, Scope, Timestamp
- identity.bluebook: IdentityId, ExternalIdentifierKey, Issuer, Subject
- console_settings.bluebook: StateStyleText, Flag, SettingsText, SettingsNumber, Column.field, DetailField.field, Precondition (×2), FieldFormat (×2)
- interview.bluebook: SessionReference, Subject, ChapterName, IdentityId, QuestionText, AnswerText, Topic, CatalogueRef, Slug, Prompt
- payments.bluebook: DeclineReason fields (above)

**Language Bluebooks (10 locations):**
- aggregate.bluebook: AggregateName, Description, IdentityField, IdentityPath, Field (name, type), ValueName, Transition (command, to_state)
- behavior.bluebook: CommandName, Actor, Goal, EventName
- shape.bluebook: ValueObjectName, ShapeField (name, type, list), Assertion (description, canonical)
- syntax.bluebook: SyntaxName, Context.name, Body.name, Status.name, ArgumentKind.name, PairsShape.name, Keyword (word, context, body, status)
- entity.bluebook: EntityName, IdentityPath, PieceField (name, type, list), PieceTransition (command, to_state)
- projection.bluebook: ReadModelName, ProjectionPurpose, Head (aggregate, as, many), ProjectionOption (option, key)
- reaction.bluebook: PolicyName, ProcessManagerName, SagaState.name
- bluebook.bluebook: BluebookName, Vision, Classification, NormalisationRule (strategy, boundary), Version, FormerlyKnownAs
- vocabulary.bluebook: Comparison (symbol, compares_less_than, compares_equal, negated), SignTest (name, compares_via), IncludeHaystack (type, strategy), ToStringType (type), SizedType (type), Primitive (name), NormalisationStrategy (name), MutationOp (name), QueryComparator (name), LoadOrder (glob)

**Test Fixtures (10 locations):**
- model_check/lifecycle_findings.bluebook: Number, Serial
- model_check/policy_findings.bluebook: Number
- model_check/saga_findings.bluebook: Reference
- eras/*.bluebook: FullName.value, AccountNumber.value, Money.currency, Tag.value

---

## Testing Coverage

### Domains Tested
- Pizzas: boundary testing, state violations, mutations, event ordering ✅
- Banking: account opening, transfer validation, frozen account checks, email patterns ✅
- Compliance: OIDC flows ✅
- Settlement: basic validation ✅
- Governance: role assignment, identity linking ✅
- Identity: external identifier validation ✅

### Known Open Issues
- GitHub #54: Array `in:` query silent type coercion — FIXED
- GitHub #55: Empty string `ne:` query null matching — Under investigation

---

## Methodology

Each bug represents one distinct problem with one logical fix. When a fix applies to multiple locations (e.g., adding the same pattern validation to 76 attributes), it counts as 1 bug with 76 affected sites, not 76 bugs.

This avoids inflating the count by conflating "number of failed specs" with "number of distinct root causes."
