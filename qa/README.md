# QA Testing Suite for hecksagain

This folder contains automated testing scripts and documentation for systematic quality assurance testing of the hecksagain domain runtime.

## Contents

### Guides
- **BUG_FINDING_METHODOLOGY.md** - How to systematically find bugs using 8 categories of adversarial testing

### Scripts

#### qa_runner.rb
Automated corpus structure validator. Ensures all test fixture files have valid structure.

```bash
ruby qa/qa_runner.rb --verbose
```

**What it does:**
- Validates all .json corpus files in spec/corpus/
- Checks that steps have verb or query
- Verifies required args are present
- Reports pass/fail summary

#### qa_adversarial_fixed.rb
Comprehensive adversarial test suite. Run against any domain to find edge cases, boundary violations, and state corruption bugs.

```bash
rspec qa/qa_adversarial_fixed.rb --format progress
```

**Test Categories Covered:**
1. Boundary conditions (zero, negative, max values)
2. Empty/null string handling
3. State violation attacks (commands in wrong order)
4. Identity/collision testing (duplicate IDs, SQL injection patterns)
5. Concurrency-like rapid mutations
6. Special character handling (unicode, SQL-like strings)
7. Event stream integrity
8. Topping limit enforcement

## How to Use

### Quick Validation
```bash
ruby qa/qa_runner.rb
```

### Run Adversarial Tests on Pizzas
```bash
rspec qa/qa_adversarial_fixed.rb -k "Pizzas"
```

### Run Adversarial Tests on Banking
```bash
rspec qa/qa_adversarial_fixed.rb -k "Banking"
```

### Full Run
```bash
rspec qa/qa_adversarial_fixed.rb --format progress
```

## What These Tests Look For

### State Corruption
- Mutable arrays/hashes after dispatch
- Incomplete mutations due to refused ensures
- Lost state during rapid operations

### Validation Gaps
- Empty string acceptance where forbidden
- Zero/negative values accepted
- Invalid enum values accepted
- Missing required fields

### Boundary Violations
- Operations on non-existent aggregates
- Operations in wrong lifecycle state
- Duplicate operations (buying twice, reversing twice)

### Data Integrity
- Event ordering under stress
- No data loss on rapid mutations
- Proper identity handling
- Safe encoding of special characters

## Bug Found & Fixed

### List Attributes Now Frozen (2026-08-11)
Previously, list attributes (toppings, ledgers, etc.) could be mutated after dispatch:
```ruby
# This used to work (BUG):
result.state[:toppings] << { malicious: "injection" }

# Now properly raises FrozenError:
result.state[:toppings] # frozen? => true
```

**Fixed in:** Commit 8baa725
- Instance#defaults freezes empty lists
- MutationApplier#appended freezes new arrays
- Coercion#hydrate_entity_list freezes hydrated lists

## Known Issues

### Nested Value Object Invariants Not Validated
Invariants declared on nested value objects are not checked during dispatch. For example:
```ruby
# Price invariant: { cents > 0 }
# But when nested in Pizza:
{ price_cents: { cents: 0 } }  # Accepted (should be rejected)
```

Root cause: `Value::Coercion.build()` only validates top-level VOs
Impact: Any domain with nested VOs has this gap
Status: Requires architectural change to fix

### Invalid Closed-Set Values Accepted
Same root cause as nested VO invariants (blocked by above issue)

## Contributing to QA

When adding new tests:
1. Follow the 8 adversarial testing categories
2. Start with an expectation
3. Try to violate it
4. Document findings in ADVERSARIAL_FINDINGS.md
5. Create regression tests if fixable

See BUG_FINDING_METHODOLOGY.md for detailed approach.
