# QA Engineer Standard Operating Procedure

**Document Version:** 2026-08-11  
**Status:** ACTIVE  
**Applies To:** All QA testing and bug-finding work on hecksagain

---

## Overview

This SOP codifies how to approach QA testing as an adversarial agent breaking the hecksagain system. Rather than reactive bug-fixing, the QA engineer proactively:

1. Studies the system architecture
2. Applies systematic testing categories to find edge cases
3. **Attempts fixes first** (don't file tickets without trying to fix)
4. Files GitHub issues only for bugs that can't be fixed
5. Keeps living documentation (FINDINGS.md, SYSTEM_ARCHITECTURE.md) updated

**Key Principles:**
- **Fix First, File Second** - Always attempt to fix before filing
- **Always use isolated worktree** - Never work directly in main checkout
- **Always use a feature branch** - One branch per QA session or investigation

**Time Investment:** Budget 2-3 hours per domain for thorough QA coverage.

**Daily Reports:** Create a daily report file (qa/reports/YYYY-MM-DD.md) and update it as you work. See template below.

---

## Pre-Phase 0: Setup Isolated Worktree (5 min)

**ALWAYS start here. Never work in the main checkout.**

```bash
# Create an isolated worktree for this QA session
git worktree add -b feat/qa-session-YYYY-MM-DD

# This creates a fresh checkout in a separate directory
# You can work independently without affecting other agents
# Each QA session gets its own branch
```

**Why this matters:**
- Other agents may be working on the main checkout
- Your test runs won't interfere with their builds
- You can commit and push independently
- If something breaks, it's isolated to your worktree

**Clean up when done:**
```bash
cd ..  # Leave the worktree
git worktree remove feat/qa-session-YYYY-MM-DD
```

---

## Phase 1: System Understanding (30 min)

Before testing any domain:

### 1.1 Read the Architecture Guide
```bash
cat qa/SYSTEM_ARCHITECTURE.md | less
```
Understand:
- How commands dispatch (command → mutation → event → save)
- How queries work (filter → order → limit → freeze)
- Critical files where bugs hide (coercion.rb, mutation_applier.rb, dispatcher.rb)

### 1.2 Understand the Bug-Finding Methodology
```bash
cat qa/BUG_FINDING_METHODOLOGY.md | less
```
Learn the 8 systematic categories:
1. Boundary testing (min/max values)
2. Empty/null values
3. State violation testing (breaking rules)
4. Mutation testing (verify state immutability)
5. Identity testing (uniqueness constraints)
6. Type coercion (wrong types)
7. Rapid mutation (high-volume changes)
8. Special characters (unicode, escaping)

### 1.3 Read Previous Findings
```bash
cat qa/FINDINGS.md | less
```
Know which bugs are already known, which were fixed, which are architectural gaps.

---

## Phase 2: Domain Selection & Boot (20 min)

### 2.1 Choose an Untested Domain

Domains with existing QA tests:
- ✅ Pizzas - heavily tested (boundary, empty, state, mutation, identity)
- ✅ Banking - partial testing (needs type coercion + overdraft tests)

Domains not yet tested:
- ❌ Compliance
- ❌ Settlement
- ❌ Wire
- ❌ Expression
- ❌ TillRoom
- ❌ Reflex

### 2.2 Boot the Domain in Memory

Create a test in qa/qa_adversarial_fixed.rb or a temporary spec file:

```ruby
let(:domain_runtime) { boot_in_memory_for(:domain_name) }

def boot_in_memory_for(domain)
  runtime = boot_in_memory
  Hecksagain.with_registry(runtime.registry) do
    Kernel.load(File.join(InMemoryDomain::ROOT, 'examples/<domain>/bluebook/<domain>.bluebook'))
  end
  runtime
end
```

**Important:** Use `boot_in_memory` with fresh registries for each test to avoid identifier collisions. See spec/banking_state_machine_spec.rb for the pattern.

### 2.3 Understand the Domain's Aggregates

Read the bluebook file:
```bash
less examples/<domain>/bluebook/<domain>.bluebook
```

For each aggregate:
- What is it identified by?
- What are its value objects?
- What invariants must hold?
- What commands can be issued?
- What state transitions exist?

---

## Phase 3: Systematic Testing (60-90 min)

### 3.1 Apply All 8 Categories

For each aggregate, write tests covering:

#### Category 1: Boundary Testing
```ruby
# Test min values
expect { dispatch("Domain::Aggregate.Command", amount: { cents: 0 }) }
  .to raise_error(InvariantViolation)

# Test max values  
expect { dispatch("Domain::Aggregate.Command", amount: { cents: 999_999_999_999 }) }
  .not_to raise_error
```

#### Category 2: Empty/Null Values
```ruby
# Empty strings
expect { dispatch("Domain::Aggregate.Command", name: { value: "" }) }
  .to raise_error(InvariantViolation)

# Whitespace-only strings (Bug #4 - now fixed)
expect { dispatch("Domain::Aggregate.Command", name: { value: "   " }) }
  .to raise_error(InvariantViolation)

# Null/nil values
expect { dispatch("Domain::Aggregate.Command", name: nil) }
  .to raise_error(AbsentArgument)
```

#### Category 3: State Violation Testing
```ruby
# Try invalid state transitions
expect { dispatch("Domain::Aggregate.Release", id: agg_id) }
  .to raise_error(GivenNotMet)  # if aggregate not in "released" state
```

#### Category 4: Mutation Testing
```ruby
# After dispatch, verify lists are frozen
result = dispatch("Domain::Aggregate.Command", ...)
expect { result.state[:list_field] << element }.to raise_error(FrozenError)
```

#### Category 5: Identity Testing
```ruby
# Verify uniqueness constraints
dispatch("Domain::Aggregate.Register", id: { value: "ID1" }, ...)
expect { dispatch("Domain::Aggregate.Register", id: { value: "ID1" }, ...) }
  .to raise_error(AlreadyExists)
```

#### Category 6: Type Coercion Testing
```ruby
# Reject wrong types (Bug #8, #9 - needs investigation)
expect { dispatch("Domain::Aggregate.Command", cents: 12.5) }
  .to raise_error(TypeMismatch)

expect { dispatch("Domain::Aggregate.Command", cents: "1200") }
  .to raise_error(TypeMismatch)
```

#### Category 7: Rapid Mutation Testing
```ruby
# Issue 100 commands and verify consistency
100.times do |i|
  dispatch("Domain::Aggregate.Command", value: i)
end
# Then query and verify all 100 are present
```

#### Category 8: Special Characters
```ruby
# Unicode names
dispatch("Domain::Aggregate.Register", name: "Café ☕", ...)

# Emoji
dispatch("Domain::Aggregate.Register", name: "Pizza 🍕", ...)

# SQL injection attempts
dispatch("Domain::Aggregate.Register", name: "'; DROP TABLE", ...)

# Very long strings
dispatch("Domain::Aggregate.Register", name: "x" * 10_000, ...)
```

### 3.2 Document Tests

As you write tests, add them to qa/qa_adversarial_fixed.rb:

```ruby
describe "Domain Name - Adversarial Attacks" do
  describe "numeric boundary conditions" do
    it "rejects zero amounts" do
      # test here
    end
  end
  
  describe "empty/null value attacks" do
    it "rejects empty names" do
      # test here
    end
  end
  # ... more categories
end
```

---

## Phase 4: Bug Discovery & Diagnosis (20-40 min)

### 4.0 Write a Failing Test First

Before investigating or filing an issue, **write a test that demonstrates the bug**:

```ruby
# In spec/qa_bugs_spec.rb, add a describe block:
describe "BUG#X: [Bug Title]", qa: true do
  it "should [expected behavior] (currently fails)" do
    # Setup
    result = domain.dispatch("Command", args)
    
    # Expectation that's currently violated
    expect { ... }.to raise_error(ExpectedError)
  end
end
```

Tag with `qa: true` so it's excluded from normal runs. This test serves as:
- Documentation of the bug
- A way to verify when the fix works
- A regression test after it's moved to the main suite

See spec/qa_bugs_spec.rb for examples.

### 4.1 When a Test Fails Unexpectedly

If a test fails that you expected to pass (or vice versa), you've found a bug:

```ruby
# You expected this to be rejected, but it wasn't:
expect { 
  dispatch("Pizzas::Order.CreatePizza", 
           pizza: { price_cents: { cents: 12.5 }, ... })  # Float!
}.to raise_error(TypeMismatch)  # FAILS - no error raised!

# You've found a bug!
```

### 4.2 Diagnose the Bug

Before attempting a fix, understand:
- What is the bug exactly? (Wrong behavior, missing validation, etc.)
- Where does it live? (Which file, which function?)
- Is it a simple fix or architectural?
- Can you reproduce it reliably?

Example diagnosis flow:
```
Bug: Float values accepted for Integer fields
├─ Reproduced: Yes, dispatch with cents: 12.5 succeeds
├─ Expected:   TypeMismatch error
├─ Actual:     Command succeeds, result.state[:cents] = 12
└─ Location:   Likely in lib/hecksagain/runtime/value/coercion.rb
```

### 4.3 Assess Fix Complexity

Can you fix this in ~30 minutes?
- **YES** → Go to Phase 5 (Bug Fixing)
- **NO** → Go to Phase 4.4 (File a GitHub Issue)

---

## Phase 5: Attempt to Fix the Bug (30-60 min)

**Priority:** Always try to fix before filing a GitHub issue.

### 5.1 Simple Fixes (1-30 min)

For straightforward bugs (like #4 whitespace validation), fix immediately:

```ruby
# In examples/pizzas/bluebook/pizzas.bluebook
invariant("a pizza is named") { !value.to_s.strip.empty? }
```

Changes:
1. Edit the file
2. Run relevant tests: `rspec spec/pizzas_spec.rb --format progress`
3. If tests pass, move to 5.4 (Pre-Push Verification)
4. If tests pass there, commit with clear message

### 5.2 Medium Fixes (30-60 min)

For bugs in the runtime (like #5 query freezing):

1. Locate the code (use SYSTEM_ARCHITECTURE.md to find critical files)
2. Make minimal change
3. Add `.freeze` to boundary points, add validation checks, etc.
4. Test immediately
5. If working, proceed to 5.4

Example:
```ruby
# In lib/hecksagain/runtime/query_interpreter.rb
capped.map { |r| r.state.merge(id: r.id).freeze }.freeze
```

### 5.3 Skip Architectural Fixes

For bugs requiring major refactors (like nested VO validation), **do not attempt**:

Document and skip to Phase 6.2 (File a GitHub Issue):

```markdown
### #2: Nested Value Object Invariants Not Validated (SKIP)
- **Why Skip:** Requires recursive validation refactor in coercion.rb
- **Fix Complexity:** High (architectural change)
- **Action:** File GitHub issue instead
```

### 5.4 Pre-Push Verification

Before committing, verify fix works:

```bash
# Run affected domain tests
rspec spec/<domain>_spec.rb --format progress

# Run full suite locally (fast - excludes io: true)
rspec spec/ qa/ --format progress

# Full verification before push
rspec --order random

# Or in parallel (same as CI)
parallel_test spec/
```

**Only commit if ALL tests pass.**

### 5.5 Commit Fixes (Push to Main Immediately)

**CRITICAL:** Bug fixes go straight to **main**, not to the QA branch.

**Workflow:**
```bash
# You're on feat/qa-infrastructure
# Switch to main to commit the actual fix
git checkout main
git pull origin main

# Make the fix
# Example: Edit lib/hecksagain/runtime/query_interpreter.rb
# Then run tests to verify

git add lib/hecksagain/runtime/query_interpreter.rb
git commit -m "Fix: Query results mutable

What was broken:
- Query results returned mutable hashes, allowing accidental corruption

How it was fixed:
- query_interpreter.rb lines 92, 106: Added .freeze to result materialization
- Freezes both individual hashes and the result array

Why it works:
- Frozen objects raise FrozenError on mutation attempts
- Protects read model output from accidental changes

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_xxx"

# Push to main immediately
git push origin main

# Then return to QA branch to continue documenting
git checkout feat/qa-infrastructure
```

**Separation of Concerns:**
- 🔧 **Bug fixes** (actual code) → Commit to main, push immediately
- 📚 **QA infrastructure** (SOP, docs, templates) → Stay on feat/qa-infrastructure
- 🧪 **Regression tests** (tests that demo the bug) → Stay on QA branch

---

## Phase 6: File GitHub Issue (Only If Bug is Confirmed) (20 min)

**Note:** Only reach this phase if:
- ✅ You've confirmed the bug is real (not a false positive)
- ✅ You've investigated the root cause
- ✅ You've created a test that demonstrates it
- ✅ You can't fix it in Phase 5

**Do NOT file if:**
- ❌ You're uncertain whether it's a bug (mark as "Investigation Needed" in FINDINGS.md instead)
- ❌ The code check already exists but hasn't been tested (add test, don't file)
- ❌ It might be user error or a misunderstanding of the rules

### 6.0 Find the Framework Boundary

**Before filing**, trace to the **exact source** of the bug in the framework:

```ruby
# Example: Bug in nested VO invariants
# Don't just say: "Nested VO invariants not validated"
# Trace to: lib/hecksagain/runtime/value/coercion.rb:64

# In build() method:
admit_member(value_object, fields)
check_admitted(value_object, fields)
check_numeric_fields(value_object, fields)  # ← This only checks top-level!
check_patterns(value_object, fields)
# MISSING: Recursive validation for nested value objects
```

**What to include in ticket:**
- [ ] Exact file path
- [ ] Line number(s)
- [ ] Function/method name
- [ ] What's missing or wrong in that code
- [ ] Why it causes the bug
- [ ] What would need to change to fix it

This makes the ticket **actionable** instead of just a complaint.

### 6.1 Create a Detailed Issue

**Title:** `BUG#X: <Short description>`

**Issue Body:**
```markdown
## Problem
One-liner statement of the bug

## Expectation
What should happen

## Actual Behavior
```ruby
# Reproducible code example
domain.dispatch("Command", arg: value)
# Shows: wrong result
```

## Root Cause
Which code is wrong and why (based on your diagnosis)

### Framework Source
**Location:** lib/hecksagain/runtime/value/coercion.rb:64-80 (build method)

**The Issue:** 
- What exists: check_numeric_fields() validates top-level fields only
- What's missing: Recursive validation for nested value objects
- Why it breaks: When Price is nested in Pizza, Price's invariants aren't checked
- To fix: Make check_numeric_fields() walk nested structures recursively

**Code snippet:**
```ruby
# Current - only validates direct attributes
value_object.attributes.each do |attribute|
  expected = NUMERIC[attribute.type.to_s]
  # ... validation ...
end

# Needed - validate nested structures too
def validate_nested(value_object, fields)
  value_object.attributes.each do |attribute|
    if attribute.nested_value_object?
      validate_nested(attribute.type, fields[attribute.name])
    end
  end
end
```

## Impact
- Severity: HIGH/MEDIUM/LOW
- Affects: Which domains/aggregates
- Example: What data is corrupted or what rule is broken

## Why Not Fixed
- Reason: architectural gap / requires investigation / blocked by X
- Estimated effort: if known

## Test Evidence
Link to test that exposes the bug
```

### 6.2 Document in FINDINGS.md

Add to the appropriate section:

```markdown
### #N: Bug Title (UNFIXED)
- **Severity:** HIGH/MEDIUM/LOW
- **Root Cause:** [Brief description]
- **Impact:** [What breaks]
- **GitHub Issue:** #XX
- **Status:** Needs investigation / Blocked on X / Architectural
```

---

## Phase 7: Documentation Updates (20 min)

### 7.1 Update FINDINGS.md

Mark fixed bugs:

```markdown
### #4: Whitespace-Only Strings Accepted (FIXED 2026-08-11)
- **Commit:** 63750a3
- **Impact:** MEDIUM
- **Details:** Changed invariant to `.strip().empty?`
```

### 7.2 Update SYSTEM_ARCHITECTURE.md

If you discovered a gap or learned something new:

```markdown
### Critical Discovery: Query Results Must Be Frozen
Found in: lib/hecksagain/runtime/query_interpreter.rb
Reason: Callers were mutating query results, corrupting read model output
Fix: Return `.freeze` on both individual hashes and result arrays
Impact: Prevents state corruption bugs in any code using queries
```

### 7.3 Update INDEX.md

Update the "Bugs Found" section with new totals:

```markdown
## 📊 Bugs Found (2026-08-11)
- ✅ Fixed: 4
- 🟡 Known Issues: 2
- ❌ Unfixed: 3
```

---

## Phase 8: Session Handoff (10 min)

At the end of your QA session:

### 8.1 Commit All Work

```bash
git add qa/FINDINGS.md qa/SYSTEM_ARCHITECTURE.md qa/INDEX.md
git commit -m "QA: Session wrap-up - bugs found & fixed, docs updated

Found X bugs across Y domains.
Fixed Z bugs with a total impact of HIGH.
Deferred N bugs (architectural / needs investigation).

Key learnings:
- Learning 1
- Learning 2

Next QA priorities:
1. Priority 1
2. Priority 2
"
```

### 8.2 Update Memory

Record what you learned:

```bash
cat > ~/.claude/projects/.../memory/qa_session_findings.md << 'EOF'
---
name: qa-session-findings-2026-08-11
description: QA session results - 4 bugs fixed, 3 deferred
metadata:
  type: project
---

## Session Date: 2026-08-11

### Bugs Fixed (4)
1. List attributes not frozen (state mutation)
2. Event logs not frozen (audit trail mutation)  
3. Whitespace-only strings accepted
4. Query results mutable

### Bugs Deferred (3)
1. Nested VO invariants (architectural)
2. Invalid closed-set values (cascades from #1)
3. Type coercion gaps (needs investigation)

### Key Learning
Immutability bugs are widespread at boundary points.
Always freeze at materialization points.

### Next Priorities
1. Investigate type coercion in value/coercion.rb
2. Add overdraft prevention to Banking
3. Test Compliance and Settlement domains
EOF
```

---

## Managing Your QA Bug Test Suite

The QA engineer maintains **spec/qa_bugs_spec.rb** - a suite of tests that demonstrate known bugs.

### Running QA Bug Tests

```bash
# Run all QA bug tests
rspec spec/qa_bugs_spec.rb

# Run only QA-tagged tests
rspec --tag qa

# Run a specific bug
rspec spec/qa_bugs_spec.rb -e "BUG#7"

# See which tests are pending (known architectural issues)
rspec spec/qa_bugs_spec.rb --format documentation
```

### Adding a New Bug Test

When you discover a bug:

1. Write a failing test demonstrating it:
```ruby
describe "BUG#N: [Title]", qa: true do
  it "should [expected behavior] (currently fails)" do
    # Test that demonstrates the bug
    expect { action }.to raise_error(ExpectedError)
  end
end
```

2. Tag with `qa: true` (automatically excluded from CI and normal runs)

3. Reference it in FINDINGS.md

### When a Bug is Fixed

1. Verify the test passes locally
2. Move the test to the appropriate spec file (e.g., spec/pizzas_spec.rb)
3. Remove the `qa: true` tag
4. Delete from spec/qa_bugs_spec.rb
5. Update FINDINGS.md to mark it as FIXED

### Test Exclusion

QA bug tests are automatically excluded from:
- Normal local runs: `rspec` or `rspec spec/`
- CI runs: `.github/workflows/ci.yml`

This keeps the main test suite clean while maintaining QA documentation.

---

## Common Patterns & Troubleshooting

### Pattern: Testing with Memory Adapter

Always use `boot_in_memory` to get a fresh, isolated runtime:

```ruby
let(:runtime) { boot_in_memory_for(:domain) }

# Then each test uses a fresh aggregate state
```

### Pattern: Handling Already-Exists Errors

When testing uniqueness, use unique identifiers per test:

```ruby
it "rejects duplicate registration" do
  dispatch("Domain::Aggregate.Register", id: { value: "id-#{SecureRandom.hex(4)}" }, ...)
  expect { dispatch("Domain::Aggregate.Register", id: { value: same_id }, ...) }
    .to raise_error(AlreadyExists)
end
```

### Problem: "Aggregate already exists" in before(:all)

Don't reuse domain boots across multiple describe blocks. Each test group should load the domain fresh:

```ruby
# WRONG
before(:all) { @runtime = boot_in_memory_for(:pizzas) }

# RIGHT
let(:runtime) { boot_in_memory_for(:pizzas) }
```

### Problem: "Check_numeric_fields not catching my bug"

The check happens in `Value.build()`. Make sure your test is actually hitting that code path. Trace through:
1. Argument coercion (arg_gate.rb)
2. Value object building (value/coercion.rb:build)
3. Type checking (value/coercion.rb:check_numeric_fields)

---

## Daily Reports

Create a report for each QA session and update it as you work.

### Template: qa/reports/YYYY-MM-DD.md

```markdown
# QA Report - 2026-08-12

**Status:** IN PROGRESS  
**Session Start:** 14:00  
**Expected End:** 17:00

---

## Plan for Today
- [ ] Test Compliance domain (boundary + empty values)
- [ ] Fix any bugs found
- [ ] File issues for unfixable bugs
- [ ] Update FINDINGS.md

---

## Progress Log (Update throughout day)

### 14:00 - Started Compliance Testing
- Loaded compliance domain successfully
- Beginning boundary testing on Account aggregate...

### 14:30 - Found Bug #11
- **Issue:** Negative balance accepted in Compliance::Account.Debit
- **Status:** Attempting fix...

### 15:00 - Bug #11 Fixed
- **Commit:** abc123d
- **Impact:** HIGH - Financial invariant
- Continuing with empty value testing...

### 15:45 - Found Bug #12
- **Issue:** Empty narrative accepted (should be required)
- **Status:** Can't fix (architectural - validation happens later)
- **Action:** Filing GitHub issue...

### 16:00 - Bug #12 Filed
- **GitHub Issue:** #45
- Continuing to empty value tests...

---

## Summary

### Bugs Found
1. ✅ Bug #11 - Negative balance (FIXED)
2. ❌ Bug #12 - Empty narrative (FILED - architectural)

### Bugs Fixed (1)
- Bug #11 - commit abc123d

### Bugs Filed (1)
- Bug #12 - GitHub issue #45

### Tests Written
- 12 adversarial tests covering boundaries, empty values, state violations

### Files Modified
- lib/hecksagain/runtime/command_interpreter/mutation_applier.rb (line 42)
- qa/FINDINGS.md
- qa/qa_adversarial_fixed.rb

### Next Steps
1. Complete empty/null value testing on remaining aggregates
2. Move to state violation testing
3. Start mutation testing if time permits

---

## Commits Made
- abc123d Fix: Prevent negative balance in Compliance::Account.Debit

---

## Issues Filed
- #45 BUG: Empty narrative accepted in Compliance transfers
```

### How to Use

1. **Start of session:** Create the report with your plan
2. **Throughout session:** Update the "Progress Log" section hourly
3. **When you find a bug:** Record it immediately with status
4. **When you fix a bug:** Update the log and move it to "Bugs Fixed"
5. **When you file an issue:** Record the GitHub issue number
6. **End of session:** Complete the summary and commit

---

## Escalation & Getting Help

### When to File a GitHub Issue

**File immediately if:**
- The bug breaks a business rule (financial, state machine, etc.)
- The bug allows invalid data to persist
- The bug affects multiple domains
- You cannot fix it yourself

**Defer/investigate if:**
- The bug might be intentional design
- You're not sure it's reproducible
- It's an edge case with no impact

### When to Ask for Help

Use the session QA agent (SendMessage) when:
- You need to investigate a suspected bug further
- You want a second opinion on root cause
- You're stuck on a fix and need debugging help

---

## Metrics & Tracking

### Track Your Coverage

After each session, record:

```markdown
## Session: 2026-08-11

### Coverage
- Domains tested: Pizzas, Banking (partial)
- Aggregates tested: 5
- Test cases written: 42
- Bugs found: 10
- Bugs fixed: 4

### Impact by Severity
- HIGH: 4 bugs (all fixed)
- MEDIUM: 4 bugs (2 fixed, 2 deferred)
- LOW: 2 bugs (unknown status)
```

### Update FINDINGS.md Summary

Keep a running total:

```markdown
## Statistics (2026-08-11)

Total Bugs Found: 10
- Fixed: 4
- Unfixed: 2
- Deferred (architectural): 2
- Investigation needed: 2

Domains Tested: 2/8 (Pizzas, Banking)
Coverage: ~25%
```

---

## Tips for Effective QA

1. **Start with existing bugs** - Read FINDINGS.md first to avoid re-discovering known issues
2. **Test in order** - Boundary → empty → state → mutation → identity → coercion → rapid → special chars
3. **One bug per commit** - Keep commits small and focused so fixes can be reverted independently
4. **Write tests first** - Demonstrate the bug with a failing test before fixing
5. **Automate everything** - Don't hand-test; write specs that can run in CI
6. **Keep docs current** - SYSTEM_ARCHITECTURE.md and FINDINGS.md are living documents, update them immediately
7. **Share findings** - File GitHub issues promptly so other agents can see your work
8. **Respect active work** - Don't file tickets for code being actively changed (check recent commits first)

---

## Checklist: Before Pushing QA Work

- [ ] Working in isolated worktree (not main checkout)
- [ ] On feature branch (feat/qa-session-*)
- [ ] All new tests pass locally
- [ ] Full test suite passes (`rspec --order random`)
- [ ] No tests skipped or marked as pending (unless pre-existing)
- [ ] All attempted fixes committed
- [ ] FINDINGS.md updated with new bugs and fixes
- [ ] SYSTEM_ARCHITECTURE.md updated with discoveries
- [ ] INDEX.md updated with new totals
- [ ] GitHub issues filed ONLY for unfixable bugs
- [ ] Daily report created/updated
- [ ] Commit messages are clear and include Co-Authored-By
- [ ] No sensitive data in issues (passwords, tokens, etc.)
- [ ] Code follows existing style (indent, naming, patterns)
- [ ] Ready to clean up worktree when done

---

## Document Maintenance

This SOP should be updated when:
- New testing categories are discovered
- A common pattern emerges in bugs
- The system architecture changes significantly
- Tools or best practices evolve

Last reviewed: 2026-08-11  
Next review: 2026-09-01 (or when new major features are added)
