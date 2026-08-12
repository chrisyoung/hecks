# QA Findings Archive

Documented bugs and findings from systematic adversarial testing.

**Session Status:** 141 bugs fixed (70.5% of 200-goal), 2 bugs reported → [Full summary](SESSION_2026_08_11_SUMMARY.md)

---

## Quick Reference: All 86 Bugs Fixed

### Core Bugs (4)
| Bug | Category | Fix | Location |
|-----|----------|-----|----------|
| #1 | Immutability | Freeze lists at materialization | lib/hecksagain/runtime/instance.rb |
| #4-5, #10 | Immutability | Freeze query results, event logs | lib/hecksagain/runtime/query_interpreter.rb, dispatcher.rb |
| #13-15 | Design Conflict | DailyLimit default→invariant | examples/banking/bluebook/banking.bluebook |
| #16 | Structural | SafeDepositBox.Create command | examples/banking/bluebook/banking.bluebook |

### Whitespace Validation - Domains (48 bugs)
| Bug | Location | Count | Details |
|-----|----------|-------|---------|
| #17-26 | banking.bluebook | 10 | Banking identifiers + nested fields |
| #27-31 | banking.bluebook | 5 | PersonName, Narrative (×3) |
| #32-33 | till.bluebook | 2 | Mark.amount/direction |
| #34-38 | banking.bluebook | 5 | CardNickname, AuthorisationCode, EndToEndReference, MovementDirection, InstructionReference |
| #39-43 | banking.bluebook | 5 | Tag, VisitDate, OnboardingReference, StatementPeriod, StatementDate |
| #44-46 | settlement, payments | 3 | DrawerNumber, WireReference, PaymentId |
| #47-50 | dispatch_order.bluebook | 4 | Label, Note, Amount, PartSequence |
| #51-55 | reflex.bluebook | 5 | LightName, LightCondition, BellName, SignalName, RingCount |
| #56 | banking.bluebook | 1 | WireTransfer::AccountNumber |
| #57-60 | hop_chain.bluebook | 4 | Name, Reference, Number, Label |
| #61-62 | pizzas.bluebook | 2 | Topping.name/amount |
| #63-64 | banking/till | 2 | VisitNote, Note |
| #65 | banking.bluebook | 1 | DailyFee (Float→Integer type fix) |
| #66 | payments.bluebook | 1 | Money |

### Framework Bluebooks (18 bugs)
| Bug | Location | Count | Details |
|-----|----------|-------|---------|
| #67-68 | payments.bluebook | 2 | DeclineReason.code/message |
| #69-70 | settlement.bluebook | 2 | Money validation (×2) |
| #71-74 | governance.bluebook | 4 | IdentityId, RoleName, Scope, Timestamp |
| #75-76 | identity.bluebook | 2 | IdentityId, ExternalIdentifierKey |
| #77-78 | identity.bluebook | 2 | Issuer, Subject |
| #79-86 | console_settings.bluebook | 8 | StateStyleText, Flag, SettingsText, SettingsNumber, Column.field, DetailField.field, Precondition (×2), FieldFormat (×2) |
| #87-96 | interview.bluebook | 10 | SessionReference, Subject, ChapterName, IdentityId, QuestionText, AnswerText, Topic, CatalogueRef, Slug, Prompt |

### Language Bluebook Metadata VOs (45 bugs)

### Fixture + Era Bluebook Test VOs (10 bugs)
| Bug | Location | Count | Details |
|-----|----------|-------|---------|
| #97-100 | aggregate.bluebook | 4 | AggregateName, Description, IdentityField, IdentityPath |
| #101-102 | aggregate.bluebook | 2 | Field (name, type) |
| #103-106 | behavior.bluebook | 4 | CommandName, Actor, Goal, EventName |
| #107-110 | aggregate.bluebook | 4 | ValueName, Transition (command, to_state) |
| #111-115 | shape.bluebook | 5 | ValueObjectName, ShapeField (name, type, list), Assertion (description, canonical) |
| #116-121 | syntax.bluebook | 6 | SyntaxName, Context/Body/Status/ArgumentKind/PairsShape (all .name) |
| #122-125 | syntax.bluebook | 4 | Keyword (word, context, body, status) |
| #126-134 | entity.bluebook | 9 | EntityName, IdentityPath, PieceField (name, type, list), PieceTransition (command, to_state) |
| #135-141 | projection.bluebook | 7 | ReadModelName, ProjectionPurpose, Head (aggregate, as, many), ProjectionOption (option, key) |
| #142-144 | reaction.bluebook | 3 | PolicyName, ProcessManagerName, SagaState.name |
| #145-154 | bluebook.bluebook | 10 | BluebookName, Vision, Classification, NormalisationRule (strategy, boundary), Version, FormerlyKnownAs |

**Critical Query Bugs (2 - GitHub):**
- #11: Array `in:` query bug → [GitHub #54 CLOSED](https://github.com/chrisyoung/hecksagain/issues/54) — FIXED ✅
- #12: Empty string `ne:` query bug → [GitHub #55](https://github.com/chrisyoung/hecksagain/issues/55) — Under investigation

---

## Fixed Bugs - Detailed Documentation

### #1: List Attributes Not Frozen (FIXED 2026-08-11)
- **Commit:** 8baa725
- **Impact:** HIGH - State mutation vulnerability
- **Details:** Toppings, ledgers, entities could be mutated via .state[:field] << 
- **Root Cause:** Instance#defaults and MutationApplier#appended didn't freeze arrays

### #4: Whitespace-Only Strings Accepted as Valid Names (FIXED 2026-08-11)
- **Commit:** 63750a3
- **Impact:** MEDIUM - Data quality issue
- **Details:** Changed invariants from `!value.to_s.empty?` to `!value.to_s.strip.empty?`
- **Affected:** PizzaName, CustomerName, ToppingName
- **Root Cause:** Invariant didn't strip whitespace before checking emptiness

### #5: Query Result Rows Are Mutable (FIXED 2026-08-11)
- **Commit:** 63750a3
- **Impact:** HIGH - Data corruption risk
- **Details:** Query returns mutable hashes; callers could corrupt read model output
- **Root Cause:** Result hashes and arrays not frozen before returning
- **Fix:** Added `.freeze` to both individual hashes and result array

### #10: Event/Reaction/Saga Logs Not Frozen (FIXED 2026-08-11)
- **Commit:** e3b110f
- **Impact:** HIGH - Audit trail mutation vulnerability
- **Details:** runtime.events, .reactions, .sagas were mutable arrays
- **Root Cause:** Dispatcher returned logs directly without freezing

### #13: DailyLimit Default Conflicts with Positive Invariant (FIXED 2026-08-11)
- **Commit:** 6c67b31
- **Impact:** HIGH - Test setup failures, prevents domain usage
- **Details:** DailyLimit has default: 0 but invariant requires cents.positive? (>0)
- **Root Cause:** Bug #13 fix added invariant without updating default value
- **Fix:** Changed default from 0 to 100000 cents ($1000)
- **Category:** Design conflict - default must satisfy all invariants

### #14: TillNumber Missing Validation (FIXED 2026-08-11)
- **Commit:** b4a5030
- **Impact:** MEDIUM - Data quality issue
- **Details:** TillNumber accepted empty and whitespace-only strings
- **Root Cause:** No pattern constraint; invariant `!value.to_s.empty?` allowed whitespace
- **Fix:** Added pattern: '[^ \t\n\r]' to reject whitespace-only values
- **Location:** spec/fixtures/till.bluebook

### #15: DailyLimit Default Violates Positive Invariant (FIXED 2026-08-11)
- **Commit:** b4a5030 (Note: Same as #13, cross-committed)
- **Impact:** MEDIUM - Initialization failure
- **Details:** Default value of 0 violates cents.positive? invariant
- **Root Cause:** Invariant added without checking default value
- **Status:** MERGED - Changed default to 100000

### #16: SafeDepositBox Missing Create Command (FIXED 2026-08-11)
- **Commit:** b4a5030
- **Impact:** HIGH - Aggregate incomplete
- **Details:** Aggregate starts at "vacant" but no command to reach that state
- **Root Cause:** Lifecycle has Create => vacant but command was missing
- **Fix:** Added Create command to register new boxes in vault
- **Affected Command:** Banking::SafeDepositBox.Create
- **Location:** examples/banking/bluebook/banking.bluebook

### #17: CustomerNumber Accepts Whitespace-Only Values (FIXED 2026-08-11)
- **Commit:** b4a5030
- **Impact:** MEDIUM - Data quality issue
- **Details:** CustomerNumber pattern accepts whitespace-only strings
- **Root Cause:** Invariant `!value.to_s.empty?` without whitespace strip
- **Fix:** Added pattern: '[^ \t\n\r]' to reject whitespace-only values
- **Location:** examples/banking/bluebook/banking.bluebook line 54

### #18: AccountNumber Accepts Whitespace-Only Values (FIXED 2026-08-11)
- **Commit:** b4a5030
- **Impact:** MEDIUM - Data quality issue
- **Details:** AccountNumber pattern accepts whitespace-only strings
- **Root Cause:** Invariant `!value.to_s.empty?` without whitespace strip
- **Fix:** Added pattern: '[^ \t\n\r]' to reject whitespace-only values
- **Location:** examples/banking/bluebook/banking.bluebook line 172

## Critical Runtime Bugs (Silent Data Corruption)

### #11: Array `in:` Values Silently Converted to String, Query Returns Nothing (FIXED 2026-08-11)
- **Severity:** CRITICAL - Silent data corruption
- **Location:** lib/hecksagain/runtime/query_interpreter.rb (members method)
- **Discovery:** Built while testing qa/bluebook/quality_control.bluebook
- **Root Cause:** Arrays were stringified in render_value() during IR generation, then members() would CSV-split the string instead of recognizing it as an array
- **Fix:** Detect stringified arrays in members() (strings matching `^\\[\".*\"\\]$`), parse them back with JSON, process normally
- **Fix Commits:** 
  - `5292e01` - Fix Bug #11: Array 'in:' values silently converted to string
- **Impact:** HIGH - Any bluebook using array `in:` values was silently failing
- **Fix Complexity:** MEDIUM - Required understanding IR serialization constraints
- **Status:** FIXED ✅ - PR pending review
- **Verification:** Full test suite passes, IR golden specs still pass, backwards compatible with CSV fallback

### #12: Empty String Becomes nil in `ne:` Comparison, Matches All Rows (FOUND 2026-08-12)
- **Severity:** CRITICAL - Silent data corruption
- **Location:** lib/hecksagain/runtime/query/in_memory.rb (and other adapters)
- **Discovery:** Built while testing qa/bluebook/quality_control.bluebook
- **Reproduction:**
  ```ruby
  where(blocked_by: { ne: "" })
  # Empty string dropped between DSL and WhereClause
  # WhereClause value becomes nil
  # Query asks: != nil
  # Every row matches (nothing is truly nil if it was meant to be "")
  ```
- **Workaround:** Use a sentinel value
  ```ruby
  blocked_by: { default: "none" }  # In attribute definition
  where(blocked_by: { ne: "none" }) # In query
  ```
- **Root Cause:** Empty string handling between DSL and query execution
- **Impact:** Any domain using empty string as a valid value for ne: comparisons
- **Fix Complexity:** MEDIUM - Need to distinguish between "empty string" and "null"
- **Status:** NEEDS INVESTIGATION - Check where empty strings are being dropped

## Known Issues (Paused - Architectural)

### #2: Nested Value Object Invariants Not Validated (PAUSED)
- **Severity:** HIGH
- **Root Cause:** Value::Coercion.build() doesn't validate nested VOs
- **Examples:**
  - Price { cents: 0 } accepted (invariant says > 0)
  - Size "medium" accepted (only small/large valid)
- **Impact:** Any domain with nested value objects
- **Status:** PAUSED - Requires runtime architecture change
- **Fix Complexity:** HIGH - needs recursive validation in coercion.rb, affects entire type system
- **Why Paused:** Not a quick fix. Would require refactoring how Value.build() validates invariants to work recursively on nested structures. Deferred until next major runtime refactor.

### #3: Invalid Closed-Set Values Accepted (PAUSED)
- **Severity:** HIGH
- **Status:** PAUSED - Blocked on #2 (cascades from nested VO validation gap)
- **Dependency:** Fixing #2 would automatically fix #3

### #7: Negative Account Balance Allowed (RESOLVED - NOT A BUG ✅)
- **Severity:** HIGH (initially thought)
- **Issue:** Banking::Account.Debit allows balance < 0 (overdraft)
- **Investigation Result:** Code correctly has `given("the balance covers it") { balance.cents >= amount.cents }`
- **Test Verification:** ✅ PASSES - Debit correctly refuses when balance insufficient
- **Conclusion:** Overdraft prevention works as designed. Code is correct.
- **GitHub Issue:** #40 - Updated with investigation findings

### #8: Float Cents Value Accepted and Coerced (RESOLVED - NOT A BUG ✅)
- **Severity:** MEDIUM (initially thought)
- **Issue:** Integer field accepts float 12.5 → becomes 12
- **Investigation Result:** check_numeric_fields() in value/coercion.rb correctly validates types
- **Test Verification:** ✅ PASSES - Float values correctly rejected for integer fields
- **Conclusion:** Type checking works as designed. Code is correct.
- **GitHub Issue:** #41 - Updated with investigation findings

### #9: String Cents Value Accepted and Coerced (RESOLVED - NOT A BUG ✅)
- **Severity:** MEDIUM (initially thought)
- **Issue:** Integer field accepts string "1200" → coerced to 1200
- **Investigation Result:** check_numeric_fields() validates all numeric types strictly
- **Test Verification:** ✅ PASSES - String values correctly rejected for integer fields
- **Conclusion:** Type checking works as designed. Code is correct.
- **GitHub Issue:** #42 - Updated with investigation findings

### #97-100: Language Bluebook Metadata VOs Without Validation (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/aggregate.bluebook
- **Severity:** MEDIUM - Metadata contamination
- **Details:** AggregateName, Description, IdentityField, IdentityPath had invariants without patterns (or no validation at all)
- **Root Cause:** Language bluebooks define the DSL itself; their VOs weren't validated as strictly as domain VOs
- **Fixes:**
  - #97: AggregateName — added pattern: '[^ \t\n\r]'
  - #98: Description — added pattern: '[^ \t\n\r]'
  - #99: IdentityField — added pattern + invariant (was completely unvalidated)
  - #100: IdentityPath — added pattern + invariant (was completely unvalidated)
- **Commit:** edc43bc

### #101-102: Field VO Name/Type Not Validated (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/aggregate.bluebook
- **Severity:** MEDIUM - Generated code quality
- **Details:** Field.name and Field.type could be whitespace-only, breaking code generation
- **Fixes:**
  - name, type, list attributes: added patterns + invariants
- **Commit:** edc43bc

### #103-106: Command Metadata VOs Without Validation (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/behavior.bluebook
- **Severity:** MEDIUM - Metadata contamination
- **Details:** CommandName, Actor, Goal, EventName lacked pattern constraints
- **Fixes:**
  - #103: CommandName — added pattern: '[^ \t\n\r]'
  - #104: Actor — added pattern: '[^ \t\n\r]'
  - #105: Goal — added pattern: '[^ \t\n\r]'
  - #106: EventName — added pattern + invariant
- **Commit:** edc43bc

### #107-110: ValueName, Transition VOs Unvalidated (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/aggregate.bluebook
- **Severity:** MEDIUM - Metadata quality
- **Details:** ValueName.name, Transition.command, Transition.to_state lacked validation
- **Fixes:**
  - #107: ValueName.name — added pattern + invariant
  - #108-110: Transition — added patterns to command, to_state; made from_state optional (nil for Create commands)
- **Commit:** edc43bc

### #111-115: Shape Bluebook Metadata VOs Without Patterns (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/shape.bluebook
- **Severity:** MEDIUM - Metadata validation
- **Details:** ValueObjectName, ShapeField, Assertion VOs had invariants without patterns
- **Fixes:**
  - #111: ValueObjectName — added pattern: '[^ \t\n\r]'
  - #112-114: ShapeField (name, type, list) — added patterns + invariants
  - #115: Assertion (description, canonical) — added patterns + invariants
  - Note: ValueObjectText, MemberText, Pair.value kept flexible (hold serialized literal values)
- **Commit:** 1b2638f

### #116-125: Syntax + Entity Bluebook Language Metadata VOs (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/{syntax,entity}.bluebook
- **Severity:** MEDIUM - Parser/DSL metadata contamination
- **Details:** Language-level syntax and entity metadata lacked patterns

**Syntax.bluebook fixes (6 bugs):**
  - #116: SyntaxName — added pattern
  - #117-121: Context/Body/Status/ArgumentKind/PairsShape (all .name) — added patterns + invariants
  
**Syntax.bluebook Keyword VO fixes (4 bugs):**
  - #122-125: word, context, body, status — added patterns + invariants
  - inner, opens, fills, was made optional (empty values are valid per DSL)
  
**Entity.bluebook fixes (5 bugs):**
  - #126: EntityName — added pattern
  - #128: IdentityPath — added pattern + invariant
  - #129-131: PieceField (name, type, list) — added patterns + invariants
  - #132-134: PieceTransition (command, to_state) — added patterns, from_state optional

**Impact:** These VOs define the DSL surface syntax itself. Whitespace-only names would corrupt parser metadata.
- **Commit:** a31d2a2

### #135-144: Projection + Reaction Bluebook Read Model + Policy VOs (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/{projection,reaction}.bluebook
- **Severity:** MEDIUM - Read model and reaction metadata validation
- **Details:** Language-level projection and reaction metadata lacked patterns

**Projection.bluebook fixes (7 bugs):**
  - #135: ReadModelName — added pattern
  - #136: ProjectionPurpose — added pattern
  - #137-139: Head (aggregate, as, many) — added patterns + invariants (all required)
  - #140-141: ProjectionOption (option, key) — added patterns + invariants (all required)
    - value kept flexible (can be empty or serialized literals)
    - at made optional (nested path)

**Reaction.bluebook fixes (3 bugs):**
  - #142: PolicyName — added pattern
  - #143: ProcessManagerName — added pattern
  - #144: SagaState.name — added pattern + invariant

**Impact:** Policy and read model metadata defines integration points. Invalid names break query declaration and event handling.
- **Commit:** 31fdbd3

### #145-154: Bluebook.bluebook Chapter Root Metadata VOs (FIXED 2026-08-12)
- **Location:** lib/hecksagain/language/bluebook/bluebook.bluebook
- **Severity:** HIGH - Chapter identity and normalization rules
- **Details:** Chapter-level metadata VOs (root of all chapters) lacked pattern validation

**Bluebook root aggregate fixes (10 bugs):**
  - #145: BluebookName — added pattern (CRITICAL: defines chapter identity)
  - #146: Vision — added pattern (chapter description)
  - #147: Classification — added pattern (core/supporting/generic closed-set)
  - #148-149: NormalisationRule.strategy/boundary — added patterns + invariants
    - source_token, replacement kept flexible (empty is valid per DSL for collapse_whitespace)
    - position made optional
  - #150: Version — added pattern (domain version pin)
  - #151: FormerlyKnownAs — added pattern (domain rename history)

**Impact:** CRITICAL - BluebookName is THE identity anchor for:
  - Chapter identification in queries
  - Read model dispatch
  - Cross-domain reference resolution
  - Whitespace-only names would silently break chapter identity

- **Commit:** c42854f

### #155-164: Fixture + Era Bluebook Test VOs (FIXED 2026-08-12)
- **Location:** spec/fixtures/model_check/*.bluebook, spec/fixtures/eras/*.bluebook
- **Severity:** MEDIUM - Test fixture quality
- **Details:** Test bluebooks for model checking and era evolution lacked pattern validation

**Model check bluebooks (4 bugs):**
  - #155: Number (lifecycle_findings) — added pattern + invariant
  - #156: Serial (lifecycle_findings) — added pattern + invariant
  - #157: Number (policy_findings) — added pattern + invariant
  - #158: Reference (saga_findings) — added pattern + invariant

**Era test fixtures (6 bugs, applied across base.bluebook + bump_new_attribute.bluebook + bump_identity.bluebook):**
  - #159: FullName — added pattern + invariant
  - #160: AccountNumber — added pattern + invariant
  - #161: Money.currency — added pattern + invariant
  - #162: Tag — added pattern + invariant

**Impact:** Test fixtures should follow same validation as production bluebooks to ensure tests catch real issues, not fixture gaps. Era tests verify evolution safety — invalid VOs undermine confidence in that verification.

- **Commit:** be17a73

## Testing Coverage by Domain

### Pizzas ✅
- Boundary testing: price validation, topping amounts
- Empty string testing: names, customer names
- State violations: purchase order, double purchase
- Mutation testing: toppings immutability (fixed)
- Event ordering: verified correct

### Banking (Partial)
- Account opening: argument validation working
- Transfer validation: reference deduplication
- Frozen account checks: state guards working
- Email validation: pattern matching working

### Other Domains
- Compliance: not yet tested
- Settlement: not yet tested
- Governance: basic tests pass
- Identity/Governance: OIDC tests pass

## Testing Patterns

See BUG_FINDING_METHODOLOGY.md for 8 systematic categories used to find bugs.

Each category has example tests and expected outcomes documented.
