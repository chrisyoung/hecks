# QA Findings Archive

Documented bugs and findings from systematic adversarial testing.

## Fixed Bugs (2)

### #1: List Attributes Not Frozen (FIXED 2026-08-11)
- **Commit:** 8baa725
- **Impact:** HIGH - State mutation vulnerability
- **Details:** Toppings, ledgers, entities could be mutated via .state[:field] << 
- **Root Cause:** Instance#defaults and MutationApplier#appended didn't freeze arrays

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

### #4: Whitespace-Only Strings Accepted as Valid Names (UNFIXED)
- **Severity:** MEDIUM
- **Issue:** `!value.to_s.empty?` passes "   " (whitespace)
- **Affected:** PizzaName, CustomerName, ToppingName, etc.
- **GitHub Issue:** #39
- **Fix:** Change invariant to `.strip().empty?` or pre-strip values

### #5: Query Result Rows Are Mutable (UNFIXED)
- **Severity:** HIGH - Data corruption risk
- **Issue:** Query returns mutable hashes that can be modified
- **Impact:** Callers can corrupt read model output
- **GitHub Issue:** #38
- **Fix:** Freeze hashes before returning from query_interpreter.rb

### #7: Negative Account Balance Allowed (UNFIXED)
- **Severity:** HIGH - Financial invariant violation
- **Issue:** Banking::Account.Debit allows balance < 0 (overdraft)
- **Impact:** Accounts can go unlimited negative
- **GitHub Issue:** #40
- **Fix:** Add given() check: `balance.cents >= amount.cents`

### #8: Float Cents Value Accepted and Coerced (UNFIXED)
- **Severity:** MEDIUM - Data loss via truncation
- **Issue:** Integer field accepts float 12.5 → becomes 12
- **Impact:** Silent data loss in financial amounts
- **GitHub Issue:** #41
- **Fix:** Reject floats for Integer fields, don't coerce

### #9: String Cents Value Accepted and Coerced (UNFIXED)
- **Severity:** MEDIUM - Type safety issue
- **Issue:** Integer field accepts string "1200" → coerced to 1200
- **Impact:** Type confusion, unclear coercion semantics
- **GitHub Issue:** #42
- **Fix:** Reject non-Integer types for Integer fields

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
