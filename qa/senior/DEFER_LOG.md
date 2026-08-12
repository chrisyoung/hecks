# QA Senior - Deferred Bugs Log

Permanent record of bugs we've decided to defer. **These are intentional decisions, not backlog items.** Once a bug is here, don't re-investigate it unless circumstances change (new information, priority shift, architecture refactor).

---

## Deferred Bugs

### Bug #2: Nested Value Object Invariants Not Validated (PAUSED - ARCHITECTURAL)

**Status:** PAUSED  
**Severity:** HIGH  
**Deferred Date:** 2026-08-11  
**Deferred By:** QA Senior  

**Why Deferred:**
Requires recursive validation in `Value::Coercion.build()` that affects the entire type system. Not a quick fix; would require a major runtime refactor.

**Architectural Issue:**
- `Value::Coercion.build()` validates leaf attributes but not nested value objects
- Example: `Price { cents: -100 }` accepted even though invariant says `cents > 0`
- Nested VOs are coerced but not validated recursively

**Current Workaround:**
None. Domains using nested VOs need to be aware this gap exists.

**Next Step:**
When runtime refactoring is planned (next major version), make recursive validation a first-class requirement in the coercion layer.

**Related Bugs:**
- Bug #3 (Invalid closed-set values) — blocked on this fix

---

### Bug #3: Invalid Closed-Set Values Accepted (PAUSED - BLOCKED)

**Status:** PAUSED - BLOCKED ON BUG #2  
**Severity:** HIGH  
**Deferred Date:** 2026-08-11  
**Deferred By:** QA Senior  

**Why Deferred:**
Cascades from Bug #2. Fixing nested VO validation would automatically fix this.

**Architectural Issue:**
- Closed-set fields (limited enum values) aren't validated if they're nested VOs
- Example: `Size { value: "extra-large" }` where only "small" and "large" are valid

**Current Workaround:**
None. Domains using closed-set nested VOs should add application-level validation until runtime supports it.

**Next Step:**
Fix Bug #2 first. This will resolve automatically.

**Related Bugs:**
- Bug #2 (Nested VO validation) — this depends on that

---

## Deferred Investigations (Not Bugs - False Positives)

These were investigated and determined to be working as designed.

### Bug #7: Negative Account Balance Allowed

**Status:** RESOLVED - NOT A BUG  
**Investigated Date:** 2026-08-11  

**Original Report:**
Banking::Account.Debit allows balance < 0

**Investigation Result:**
Code correctly has `given("the balance covers it") { balance.cents >= amount.cents }`

**Verification:**
✅ Test PASSES - Debit correctly refuses when balance insufficient

**Conclusion:**
Overdraft prevention is working as designed. Code is correct.

---

### Bug #8: Float Cents Value Accepted and Coerced

**Status:** RESOLVED - NOT A BUG  
**Investigated Date:** 2026-08-11  

**Original Report:**
Integer field accepts float 12.5 → becomes 12

**Investigation Result:**
`check_numeric_fields()` in value/coercion.rb correctly validates types

**Verification:**
✅ Test PASSES - Float values correctly rejected for integer fields

**Conclusion:**
Type checking is working as designed. Code is correct.

---

### Bug #9: String Cents Value Accepted and Coerced

**Status:** RESOLVED - NOT A BUG  
**Investigated Date:** 2026-08-11  

**Original Report:**
Integer field accepts string "1200" → coerced to 1200

**Investigation Result:**
`check_numeric_fields()` validates all numeric types strictly

**Verification:**
✅ Test PASSES - String values correctly rejected for integer fields

**Conclusion:**
Type checking is working as designed. Code is correct.

---

## Deferred Bugs by Category

**Architectural (Need Design Review):**
- Bug #2 — Nested VO validation
- Bug #3 — Closed-set validation (blocked on #2)

**Blocked By Another Bug:**
- Bug #3 — Blocked on Bug #2

**Waiting for Circumstances:**
- (none currently)

---

## How to Use This Log

### As a QA Engineer
If you find a bug that looks like one of these:
1. Check this log first
2. If it's here, add a comment but don't re-investigate
3. If it's not here, proceed with the fix workflow

### As a Senior QA Engineer
Before deferring a bug:
1. Add it here with full context
2. Make the decision permanent (not "someday")
3. Document why, not just "hard"
4. Check if anyone else needs to know

### As a Future Maintainer
When the architecture changes (major runtime refactor):
1. Re-read this log
2. Some deferred bugs may now be fixable
3. Update the status and move to FINDINGS.md FIXED
4. Document the refactor that made it possible

---

**Last Updated:** 2026-08-11  
**Last Updated By:** QA Senior
