# QA Findings Archive

Documented bugs and findings from systematic adversarial testing.

## Fixed Bugs (35)

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
