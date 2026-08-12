# QA Engineer Standard Operating Procedure

**Document Version:** 2026-08-11  
**Status:** ACTIVE  
**Applies To:** All QA testing and bug-finding work on hecksagain

---

## Overview

This SOP codifies how to approach QA testing as an adversarial agent breaking the hecksagain system. Rather than reactive bug-fixing, the QA engineer proactively:

1. Studies the system architecture
2. Applies systematic testing categories to find edge cases
3. Files GitHub issues with reproducible evidence
4. Attempts fixes (when possible) rather than just reporting bugs
5. Keeps living documentation (FINDINGS.md, SYSTEM_ARCHITECTURE.md) updated

**Time Investment:** Budget 2-3 hours per domain for thorough QA coverage.

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

## Phase 4: Bug Discovery (20-40 min)

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

Before filing an issue, understand:
- What is the bug exactly? (Wrong behavior, missing validation, etc.)
- Where does it live? (Which file, which function?)
- Is it architectural or a simple fix?
- Can you reproduce it reliably?

Example diagnosis flow:
```
Bug: Float values accepted for Integer fields
├─ Reproduced: Yes, dispatch with cents: 12.5 succeeds
├─ Expected:   TypeMismatch error
├─ Actual:     Command succeeds, result.state[:cents] = 12
└─ Location:   Likely in lib/hecksagain/runtime/value/coercion.rb
```

### 4.3 File a GitHub Issue

Create a detailed issue with:

**Title:** `BUG#X: <Short description>`

**Issue Body:**
```markdown
## Problem
[One-liner statement of the bug]

## Expectation
[What should happen]

## Actual Behavior
```ruby
# Reproducible code example
domain.dispatch("Command", arg: value)
```

## Root Cause
[Your diagnosis - which code is wrong and why]

## Impact
[How severe: HIGH (breaks business logic), MEDIUM (edge case), LOW (cosmetic)]

## Fix Required
[Your proposed solution, if known]

## Test Evidence
[Link to test that exposes the bug]
```

### 4.4 Document in FINDINGS.md

Add to the unfixed bugs section:

```markdown
### #N: Bug Title (UNFIXED)
- **Severity:** HIGH/MEDIUM/LOW
- **Root Cause:** [Brief description]
- **Impact:** [What breaks]
- **GitHub Issue:** #XX
- **Status:** Awaiting investigation / Blocked on X / Fixable
```

---

## Phase 5: Bug Fixing (60-120 min, if possible)

### 5.1 Attempt Simple Fixes

For straightforward bugs (like #4 whitespace validation), fix immediately:

```ruby
# In examples/pizzas/bluebook/pizzas.bluebook
invariant("a pizza is named") { !value.to_s.strip.empty? }
```

Changes:
1. Edit the file
2. Run tests to verify fix: `rspec spec/pizzas_spec.rb --format progress`
3. Commit with clear message: `Fix: Whitespace-only strings now rejected`

### 5.2 Avoid Architectural Fixes

For bugs requiring major refactors (like nested VO validation), document and defer:

```markdown
### #2: Nested Value Object Invariants Not Validated (UNFIXED)
- **Status:** Requires runtime architecture change
- **Fix Complexity:** High - would need recursive validation in coercion.rb
```

### 5.3 Commit Fixes Locally

Never push without testing:

```bash
# Run full test suite locally (fast - excludes io: true)
rspec spec/ qa/ --format progress

# Commit only when all tests pass
git add -A
git commit -m "Fix: <Brief description of fix>

Details of what was changed and why.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_xxx"
```

### 5.4 Pre-Push Verification

Before pushing, run the full test suite including slow I/O tests:

```bash
# Full verification
rspec --order random

# Or in parallel (same as CI)
parallel_test spec/
```

**DO NOT PUSH** until all tests pass.

---

## Phase 6: Documentation Updates (20 min)

### 6.1 Update FINDINGS.md

Mark fixed bugs:

```markdown
### #4: Whitespace-Only Strings Accepted (FIXED 2026-08-11)
- **Commit:** 63750a3
- **Impact:** MEDIUM
- **Details:** Changed invariant to `.strip().empty?`
```

### 6.2 Update SYSTEM_ARCHITECTURE.md

If you discovered a gap or learned something new about the system:

```markdown
### Critical Discovery: Query Results Must Be Frozen
Found in: lib/hecksagain/runtime/query_interpreter.rb
Reason: Callers were mutating query results, corrupting read model output
Fix: Return `.freeze` on both individual hashes and result arrays
Impact: Prevents state corruption bugs in any code using queries
```

### 6.3 Update INDEX.md

Update the "Bugs Found" section with new totals:

```markdown
## 📊 Bugs Found (2026-08-11)
- ✅ Fixed: 4
- 🟡 Known Issues: 2
- ❌ Unfixed: 3
```

---

## Phase 7: Session Handoff (10 min)

At the end of your QA session:

### 7.1 Commit All Documentation

```bash
git add qa/FINDINGS.md qa/SYSTEM_ARCHITECTURE.md qa/INDEX.md
git commit -m "QA: Session wrap-up - bugs found, fixes attempted, docs updated

Found X bugs across Y domains.
Fixed Z bugs with a total impact of HIGH.
Deferred N architectural issues.

Key learnings:
- Learning 1
- Learning 2

Next QA priorities:
1. Priority 1
2. Priority 2
"
```

### 7.2 Update Memory

Record what you learned for future sessions:

```bash
# Example memory entry
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
Immutability bugs are widespread at boundary points - anywhere data leaves the runtime (queries, events, lists). Always freeze at materialization points.

### Next Priorities
1. Investigate type coercion in value/coercion.rb
2. Add overdraft prevention to Banking
3. Test Compliance and Settlement domains
EOF
```

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

- [ ] All new tests pass locally
- [ ] Full test suite passes (`rspec --order random`)
- [ ] No tests skipped or marked as pending (unless pre-existing)
- [ ] FINDINGS.md updated with new bugs and fixes
- [ ] SYSTEM_ARCHITECTURE.md updated with discoveries
- [ ] INDEX.md updated with new totals
- [ ] GitHub issues filed for bugs found
- [ ] Commit messages are clear and include Co-Authored-By
- [ ] No sensitive data in issues (passwords, tokens, etc.)
- [ ] Code follows existing style (indent, naming, patterns)

---

## Document Maintenance

This SOP should be updated when:
- New testing categories are discovered
- A common pattern emerges in bugs
- The system architecture changes significantly
- Tools or best practices evolve

Last reviewed: 2026-08-11  
Next review: 2026-09-01 (or when new major features are added)
