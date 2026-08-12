# QA Findings Archive

Documented bugs and findings from systematic adversarial testing.

## Fixed Bugs

### List Attributes Not Frozen (FIXED 2026-08-11)
- **Commit:** 8baa725
- **Impact:** HIGH - State mutation vulnerability
- **Status:** ✅ FIXED
- **Details:** See README.md

## Known Issues

### Nested Value Object Invariants Not Validated (UNFIXED)
- **Severity:** HIGH
- **Root Cause:** Value::Coercion.build() doesn't validate nested VOs
- **Examples:**
  - Price { cents: 0 } accepted (invariant says > 0)
  - Size "medium" accepted (only small/large valid)
- **Impact:** Any domain with nested value objects
- **Status:** Requires runtime architecture change
- **Fix Complexity:** Medium - needs recursive validation in coercion.rb

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
