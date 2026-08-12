# QA Findings Archive

Documented bugs and findings from systematic adversarial testing.

## Fixed Bugs (4)

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
