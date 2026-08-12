# QA Next Session Priorities - Path to 200 Bugs

**Current Status:** 6 bugs found (4 fixed, 2 reported)  
**Target:** 200 bugs  
**Gap:** 194 more bugs needed  
**Session Date:** 2026-08-11

---

## Highest-Priority Opportunities (Estimated Bugs)

### Priority 1: Fix Query Pipeline Bugs (2 bugs)
**GitHub Issues #54, #55**

These are blockers for QA bluebook deployment:
- Bug #11: Array 'in:' values silently fail - fix in lib/hecksagain/runtime/query/
- Bug #12: Empty string in 'ne:' matches all - trace empty string handling

**Time estimate:** 1-2 hours  
**Impact:** Unblocks quality_control.bluebook deployment

### Priority 2: Banking Domain Comprehensive Testing (20-30 bugs)
**Location:** examples/banking/bluebook/banking.bluebook

Started but not completed. Use 8-category adversarial testing:
1. Boundary: Zero balance, negative balance, huge balance
2. Empty/Null: Empty holder names, nil values
3. State Violations: Transfer from frozen, double freeze, invalid transitions
4. Mutation: Ledger immutability, account list immutability
5. Identity: Composite key (branch_code + box_number) uniqueness
6. Type Coercion: Float/string cents values
7. Rapid: 100 concurrent accounts/transfers
8. Special Characters: Unicode in holder names, emoji
9. Fix Itself: Valid inputs after any pattern fixes

**Create:** spec/qa_banking_adversarial_spec.rb

**Expected bugs:**
- Missing validations on holder names (whitespace pattern?)
- State transition gaps
- Composite identity bugs
- Frozen state interactions

---

### Priority 3: Till Fixture Testing (15-25 bugs)
**Location:** spec/fixtures/till.bluebook

Complex POS system with state tracking, arithmetic mutations, marks list:
1. TillNumber validation (empty string, whitespace)
2. Money invariants (negative amounts)
3. Balance overflow/underflow (decrement > balance)
4. Marks list immutability
5. Optional note handling
6. Duplicate till numbers
7. Direction field validation (what are valid values?)
8. Large amounts (overflow?)
9. Mark tracking consistency

**Create:** spec/qa_till_adversarial_spec.rb

**Expected bugs:**
- No validation on TillNumber (empty/whitespace)
- PayOut doesn't check balance before decrement
- Direction field accepts any string
- Note handling edge cases

---

### Priority 4: Evolution/Era Fixtures (10-15 bugs)
**Location:** spec/fixtures/eras/*.bluebook

Schema migration bugs:
- bump_identity.bluebook: Composite identity evolution
- bump_lifecycle_field.bluebook: State machine changes
- bump_cardinality.bluebook: list_of vs single attribute
- All 9 bump_* variants

**Expected bugs:**
- Identity drift during evolution
- Lifecycle incompatibilities
- Data loss in migrations
- Type incompatibilities

---

### Priority 5: Payment/Settlement Sagas (10-15 bugs)
**Locations:**
- spec/fixtures/payments.bluebook (policy reactions)
- spec/fixtures/settlement.bluebook (transaction coordination)
- spec/fixtures/dispatch_order.bluebook (command ordering)

**Expected bugs:**
- Policy reaction timing issues
- Saga coordination failures
- Double-processing
- Event ordering violations

---

### Priority 6: Framework Bluebooks (10-15 bugs)
**Locations:**
- lib/hecksagain/framework/bluebook/identity.bluebook (already tested ✅)
- lib/hecksagain/framework/bluebook/governance.bluebook
- lib/hecksagain/framework/bluebook/deploy.bluebook
- lib/hecksagain/framework/bluebook/console_settings.bluebook

**Expected bugs:**
- RBAC role validation gaps
- Deploy target validation
- Permission inheritance issues
- Config DSL edge cases

---

### Priority 7: Language Bluebooks (Foundational - 20+ bugs)
**Locations:**
- lib/hecksagain/language/bluebook/*.bluebook
- lib/hecksagain/grammar/expression.bluebook
- lib/hecksagain/grammar/translation.bluebook

These are meta-domains used by everything else.

**Expected bugs:**
- Expression language gaps (operators, methods)
- Translation rule edge cases
- DSL syntax ambiguities
- Parsing edge cases

---

## Session Workflow (Tested)

The SOP in qa/SOP.md defines the 8-phase workflow:
1. ✅ Understand System (read bluebook)
2. ✅ Domain Boot (load in memory)
3. ✅ Systematic Testing (8 categories)
4. ✅ Bug Discovery (write failing test)
5. ✅ Attempt to Fix (fix first, file second)
6. ✅ Documentation (update FINDINGS.md)
7. ✅ GitHub Issues (only confirmed bugs)
8. ✅ Session Handoff (commit work)

**Critical gates:**
- Phase 5.4: Run full test suite before committing (MANDATORY)
- Phase 5.4: Document test results in commit message
- Category 9: Test valid inputs after fixes

---

## Quick Wins (< 30 min each)

These are likely quick fixes:
1. TillNumber whitespace validation (pattern fix like Pizzas)
2. Money.cents validation in TakeIn (negative check)
3. Note field optional handling
4. Direction field validation (closed set?)

Each of these could be 1 bug = 1 quick fix

---

## Testing Infrastructure Ready

✅ **SOP.md** - 8-phase workflow with gates  
✅ **SYSTEM_ARCHITECTURE.md** - Complete bluebook inventory  
✅ **FINDINGS.md** - Bug registry with tracking  
✅ **qa/sessions/TEMPLATE.md** - Session flow template  
✅ **Regression tests** - qa_bugs_spec.rb with 5 examples  
✅ **Memory system** - Persistent memory for future sessions  

---

## Estimation to 200 Bugs

**Bottom-up calculation:**
- Banking comprehensive: 20-30 bugs
- Till fixture: 15-25 bugs
- Evolution/era: 10-15 bugs
- Payment/settlement: 10-15 bugs
- Framework: 10-15 bugs
- Language: 20+ bugs
- Quick wins: 5-10 bugs
- Query pipeline (#11, #12 + related): 5-10 bugs

**Total estimated:** 95-135 bugs discoverable with systematic testing

**Notes:**
- Many will be fixed (quick validation gaps)
- Some will be reported (architectural)
- Some will be false positives (code works correctly)

To reach 200, will need to:
1. Test all 60+ bluebook files systematically
2. Create comprehensive adversarial test suites
3. Look for edge cases in the language itself
4. Consider cross-domain interactions

---

## Commands to Get Started

```bash
# Run existing QA tests
bundle exec rspec spec/qa_bugs_spec.rb --tag qa

# Create test for new domain
# Copy qa/sessions/TEMPLATE.md to qa/sessions/2026-08-XX-[Domain].md
# Create spec/qa_[domain]_adversarial_spec.rb

# Follow SOP workflow
cat qa/SOP.md | less

# Check architecture
cat qa/SYSTEM_ARCHITECTURE.md | less

# Update findings
vim qa/FINDINGS.md

# Create daily report
vim qa/reports/2026-08-XX.md
```

---

## Session Completion Summary

This session accomplished:
1. ✅ Fixed critical pizzas.bluebook bug (#4)
2. ✅ Hardened SOP with mandatory test verification gate
3. ✅ Added missing specs guidance
4. ✅ Discovered 2 critical query bugs (#11, #12)
5. ✅ Documented complete bluebook inventory (60+ files)
6. ✅ Established testing priorities for 200-bug goal
7. ✅ Created comprehensive infrastructure for next sessions

**Ready for:** Next QA engineer to continue systematic bug discovery

**Time to reach 200 bugs:** Estimated 20-40 hours of systematic testing with this infrastructure in place
