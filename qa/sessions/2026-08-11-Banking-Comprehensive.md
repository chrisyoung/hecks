# QA Testing Flow - 2026-08-11 Banking Domain (Comprehensive)

**Domain:** Banking  
**QA Engineer:** Claude QA  
**Session Start:** 2026-08-11  
**Status:** IN PROGRESS

---

## 📋 Test Plan

**Target Domain:** Banking (Account, Transfer, SafeDepositBox aggregates)  
**Testing Categories:** All 8 + Category 9 (test the fix itself)

Testing Categories:
- [x] Boundary testing (min/max values)
- [x] Empty/null values
- [x] State violation testing (breaking rules)
- [x] Mutation testing (immutability)
- [x] Identity testing (uniqueness)
- [x] Type coercion (wrong types)
- [x] Rapid mutation (high-volume)
- [x] Special characters (unicode/escaping)

---

## 🔄 Testing Progress

### Phase 1: Understand System ✅
**Status:** DONE

Banking domain has:
- **Account** aggregate: holder name, balance, daily_limit, frozen state
- **Transfer** lifecycle: from account to account via ports
- **SafeDepositBox** aggregate: composite identity (branch_code + box_number)
- **Critical rules:** Balance checks (no overdraft), daily limits, frozen account checks
- **Key test file:** spec/banking_state_machine_spec.rb (20 seeds, comprehensive state machine tests)

---

### Phase 2: Domain Boot & Setup ✅
**Status:** DONE

Banking boots successfully in memory with multiple accounts and transfer scenarios.
Fixture data: Real banking scenarios with multiple accounts, transfers, frozen states.

---

### Phase 3: Systematic Testing IN PROGRESS

#### Aggregate: Account

**Category 1: Boundary Testing**
- [ ] Zero balance account
  - Expected: Allowed (valid state)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Maximum balance (2^63-1 cents)
  - Expected: Allowed (Ruby big integers)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Daily limit = 0
  - Expected: Rejected (need to transfer at least something)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Negative daily limit
  - Expected: Rejected (invariant cents > 0)
  - Result: ⬜ NOT RUN
  - Notes:

**Category 2: Empty/Null Values**
- [ ] Empty holder name ("")
  - Expected: Rejected
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Whitespace-only holder name ("   ")
  - Expected: Rejected (after pattern fix)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Null/nil values for required fields
  - Expected: Rejected
  - Result: ⬜ NOT RUN
  - Notes:

**Category 3: State Violation Testing**
- [ ] Transfer from frozen account
  - Expected: Refused (given statement checks frozen)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Transfer to frozen account
  - Expected: Should work (you can receive money while frozen)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Unfreeze frozen account
  - Expected: Allowed (lifecycle has Unfreeze transition)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Double freeze
  - Expected: Refused (already frozen)
  - Result: ⬜ NOT RUN
  - Notes:

**Category 4: Mutation Testing**
- [ ] Mutate ledger after transfer
  - Expected: FrozenError (should be immutable)
  - Result: ⬜ NOT RUN
  - Notes: Critical - ledger is audit trail

- [ ] Mutate account list after query
  - Expected: FrozenError
  - Result: ⬜ NOT RUN
  - Notes:

**Category 5: Identity Testing**
- [ ] Duplicate account holder (same name)
  - Expected: Allowed (names need not be unique, holder_id is identity)
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] SafeDepositBox: branch_code + box_number uniqueness
  - Expected: Second box with same branch+number rejected
  - Result: ⬜ NOT RUN
  - Notes: Composite identity test

- [ ] SafeDepositBox: same box_number, different branch
  - Expected: Allowed (only combined uniqueness matters)
  - Result: ⬜ NOT RUN
  - Notes:

**Category 6: Type Coercion Testing**
- [ ] Float cents for balance (12.5)
  - Expected: Rejected (integer field)
  - Result: ⬜ NOT RUN
  - Notes: Should already work (check_numeric_fields)

- [ ] String cents ("5000")
  - Expected: Rejected
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Negative cents via string ("-1000")
  - Expected: Rejected (invariant and coercion)
  - Result: ⬜ NOT RUN
  - Notes:

**Category 7: Rapid Mutation Testing**
- [ ] Create 100 accounts rapidly
  - Expected: All created, no state bleeding
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Transfer between 50 pairs of accounts (100 transfers)
  - Expected: All succeed, ledgers consistent
  - Result: ⬜ NOT RUN
  - Notes:

**Category 8: Special Characters**
- [ ] Unicode holder names (José, Amélie)
  - Expected: Accepted
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Emoji in names (Mario 🍄)
  - Expected: Accepted
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] SQL injection attempts (' or '1'='1)
  - Expected: Accepted as literal string (no SQL in memory)
  - Result: ⬜ NOT RUN
  - Notes:

**Category 9: Test the Fix Itself**
- [ ] Valid account after any fix
  - Expected: Still works
  - Result: ⬜ NOT RUN
  - Notes: Ensures fixes don't break valid inputs

---

### Phase 4: Bug Discovery & Diagnosis ⬜
**Status:** NOT STARTED

**Bugs Found:** 0

---

### Phase 5: Fixing & Investigation ⬜
**Status:** NOT STARTED

---

### Phase 6: Documentation ⬜
**Status:** NOT STARTED

---

## 📊 Session Summary

### Coverage
- **Aggregates Tested:** 0 / 3 (Account, Transfer, SafeDepositBox)
- **Test Categories Applied:** 0 / 9
- **Test Cases Planned:** 30+

### Results
- **Bugs Found:** 0
- **Bugs Fixed:** 0
- **Bugs Investigated:** 0
- **Bugs Filed:** 0

### Next Steps
1. Run all planned test cases
2. Document findings in real-time
3. Fix quick wins, report blockers
4. Create follow-up test sessions

---

## 🏁 Session Status: STARTING

Ready to begin comprehensive adversarial testing of Banking domain.
