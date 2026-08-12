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

## Known Issues

### #2: Nested Value Object Invariants Not Validated (UNFIXED)
- **Severity:** HIGH
- **Root Cause:** Value::Coercion.build() doesn't validate nested VOs
- **Examples:**
  - Price { cents: 0 } accepted (invariant says > 0)
  - Size "medium" accepted (only small/large valid)
- **Impact:** Any domain with nested value objects
- **Status:** Requires runtime architecture change
- **Fix Complexity:** Medium - needs recursive validation in coercion.rb

### #3: Invalid Closed-Set Values Accepted (UNFIXED)
- **Severity:** HIGH
- **Status:** Blocked on #2 (cascades from nested VO validation gap)

### #7: Negative Account Balance Allowed (INVESTIGATION NEEDED)
- **Severity:** HIGH - Financial invariant violation
- **Issue:** Banking::Account.Debit allows balance < 0 (overdraft)
- **Impact:** Accounts can go unlimited negative
- **GitHub Issue:** #40
- **Status:** Existing code has `given("the balance covers it") { balance.cents >= amount.cents }` - appears to be in place. Needs concrete test case to verify if truly broken.

### #8: Float Cents Value Accepted and Coerced (LIKELY NOT A BUG)
- **Severity:** MEDIUM - Data loss via truncation
- **Issue:** Integer field accepts float 12.5 → becomes 12
- **Impact:** Silent data loss in financial amounts
- **GitHub Issue:** #41
- **Status:** check_numeric_fields() in value/coercion.rb maps "Integer" → Integer class and rejects non-Integer values. Code logic appears correct - needs test case to verify if this is truly a code path issue.

### #9: String Cents Value Accepted and Coerced (LIKELY NOT A BUG)
- **Severity:** MEDIUM - Type safety issue
- **Issue:** Integer field accepts string "1200" → coerced to 1200
- **Impact:** Type confusion, unclear coercion semantics
- **GitHub Issue:** #42
- **Status:** Same check_numeric_fields() logic should reject strings for Integer fields. Needs actual test case to confirm.

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
