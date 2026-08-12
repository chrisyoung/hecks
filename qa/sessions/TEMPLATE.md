# QA Testing Flow - YYYY-MM-DD

**Domain:** [Domain Name]  
**QA Engineer:** [Name]  
**Session Start:** HH:MM  
**Status:** IN PROGRESS

---

## 📋 Test Plan

**Target Domain:** [Domain Name]  
**Aggregates to Test:** [List aggregates]  
**Testing Categories:** [Mark which ones to apply]
- [ ] Boundary testing (min/max values)
- [ ] Empty/null values
- [ ] State violation testing (breaking rules)
- [ ] Mutation testing (immutability)
- [ ] Identity testing (uniqueness)
- [ ] Type coercion (wrong types)
- [ ] Rapid mutation (high-volume)
- [ ] Special characters (unicode/escaping)

---

## 🔄 Testing Progress

### Phase 1: Understand System
**Status:** ⬜ NOT STARTED

Notes:
- Read domain bluebook
- Identify aggregates and commands
- Map value objects and invariants

---

### Phase 2: Domain Boot & Setup
**Status:** ⬜ NOT STARTED

Notes:
- Boot domain in memory
- Create test fixtures
- Establish baseline state

---

### Phase 3: Systematic Testing
**Status:** ⬜ NOT STARTED

#### Aggregate: [Name]

**Boundary Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

- [ ] Test case 2: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**Empty/Null Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**State Violation Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**Mutation Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**Identity Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**Type Coercion Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**Rapid Mutation Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

**Special Characters Testing**
- [ ] Test case 1: [description]
  - Expected: [behavior]
  - Result: ⬜ NOT RUN
  - Notes:

---

### Phase 4: Bug Discovery & Diagnosis
**Status:** ⬜ NOT STARTED

**Bugs Found:**
1. **BUG#N** - [Title]
   - Test: [Which test exposed it]
   - Severity: HIGH/MEDIUM/LOW
   - Root Cause: [Investigation]
   - Status: Fix / Investigate / File
   - Notes:

---

### Phase 5: Fixing or Investigation
**Status:** ⬜ NOT STARTED

**Attempted Fixes:**
1. **BUG#N** - [Title]
   - Approach: [What you tried]
   - Result: Success / Failed
   - Commit: [hash if fixed]
   - Notes:

**Investigations:**
1. **BUG#N** - [Title]
   - Finding: [What you learned]
   - Next: [What needs investigation]
   - Notes:

---

### Phase 6: Documentation
**Status:** ⬜ NOT STARTED

- [ ] FINDINGS.md updated
- [ ] Tests added to spec/qa_bugs_spec.rb
- [ ] GitHub issues filed (if confirmed bugs)
- [ ] SOP improvements documented

---

## 📊 Session Summary

### Coverage
- **Aggregates Tested:** 0 / N
- **Test Categories Applied:** 0 / 8
- **Test Cases Run:** 0

### Results
- **Bugs Found:** 0
- **Bugs Fixed:** 0
- **Bugs Investigated:** 0
- **Bugs Filed:** 0

### Findings
- [List discoveries]

### Next Steps
1. [Priority 1]
2. [Priority 2]
3. [Priority 3]

---

## 🏁 Session Complete

**End Time:** HH:MM  
**Total Duration:** X hours Y min

**Key Takeaways:**
- [Learning 1]
- [Learning 2]

**For Next Session:**
- [Recommendation 1]
- [Recommendation 2]
