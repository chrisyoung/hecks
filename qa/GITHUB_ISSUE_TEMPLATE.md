# QA GitHub Issue Template

Use this template for filing bugs discovered during QA testing. File issues **ONLY** for bugs that couldn't be fixed in a 30-minute session.

---

## Title Format

```
BUG#N: [Short description]
```

Examples:
- `BUG#4: Whitespace-only strings accepted as valid names`
- `BUG#5: Query result rows are mutable - state corruption risk`
- `BUG#8: Float cents value accepted and coerced to integer`

---

## Issue Body Template

```markdown
## Problem
[One-liner statement of what's broken]

## Expectation
[What should happen according to the domain rules]

## Actual Behavior
```ruby
# Reproducible code example showing the bug
# Should demonstrate: wrong result, silent failure, or unexpected acceptance
```

## Root Cause
[Which code is wrong and why - from your investigation]

### Framework Source (CRITICAL - Always Include)
[This is what makes the ticket actionable. Trace to the exact boundary.]

**Location:**
- File: lib/hecksagain/runtime/...
- Line: X-Y
- Function: method_name()

**What's Wrong:**
- Current behavior: [What the code actually does]
- Expected behavior: [What it should do]
- Gap: [The specific missing piece]

**Code Reference:**
```ruby
# Show the problematic code
# Point out what's missing or wrong
# Explain why this causes the bug
```

**To Fix Would Require:**
- [Design decision needed?]
- [Architectural change needed?]
- [Recursive logic needed?]
- [New validation added?]

## Impact
**Severity:** HIGH / MEDIUM / LOW
- [Specific impact: what breaks, what data is corrupted, what rule is violated]
- [Which domains are affected]
- [Example of bad outcome]

## Why Not Fixed
[Why this wasn't fixed in the QA session]

Options:
- Requires architectural change (runtime refactor needed)
- Too complex for 30-minute fix window
- Needs additional investigation before attempting fix
- Blocked on another issue (#X)

## Fix Required
[Your proposed solution, if known]

### Option A: [Quick fix if possible]
```ruby
# Code change or pseudocode
```

### Option B: [Architectural fix if needed]
[Description of what would need to change]

## Test Evidence
- Test file: spec/qa_bugs_spec.rb or qa/qa_bugs_spec.rb
- Test name: BUG#N test case
- Commit: [hash of QA infrastructure commit with test]

### How to Reproduce
```bash
# Command to run the specific test
rspec spec/qa_bugs_spec.rb -e "BUG#N"

# Or run the adversarial test suite
rspec qa/qa_adversarial_fixed.rb
```

## Investigation Notes
[Any other findings from your investigation]

- [ ] Code check confirms issue exists
- [ ] Test case written
- [ ] Impact verified across domains
- [ ] Attempted fix unsuccessful (explain why)

## Related Issues
- Related to: #X (similar root cause)
- Cascades from: #Y (this issue causes that issue)
- Blocked by: #Z (can't fix until that is fixed)

## QA Session Reference
- Discovered in session: [date] (qa/reports/YYYY-MM-DD.md)
- QA branch: feat/qa-session-YYYY-MM-DD
- Severity assessment: [how critical is this]
```

---

## Example: Good Ticket

```markdown
## Problem
Whitespace-only strings are accepted as valid pizza names

## Expectation
PizzaName invariant requires a non-empty name. Whitespace should be treated as empty.

## Actual Behavior
```ruby
Order.CreatePizza(name: { value: "   " })  # Accepted!
# Should be rejected, but passes through
```

## Root Cause
`examples/pizzas/bluebook/pizzas.bluebook` line 18:
- Current: `invariant("a pizza is named") { !value.to_s.empty? }`
- Problem: `"   ".empty?` returns false (whitespace is not empty to Ruby)

## Impact
**Severity:** MEDIUM
- Pizza orders can have effectively nameless entries
- Read model queries return entries with only whitespace
- User-facing data quality issue

## Why Not Fixed
Actually CAN be fixed in 30 minutes - should be fixed, not filed

[This would be fixed immediately, not filed as a ticket]
```

---

## Example: Investigation Needed

```markdown
## Problem
Float values accepted for integer cents fields

## Expectation
Integer fields should only accept integer values

## Actual Behavior
```ruby
Account.Credit(amount: { cents: 12.5 })  # Accepted!
# Should reject, but gets coerced to 12
```

## Root Cause
Investigation suggests `Value::Coercion::check_numeric_fields()` should catch this.
Found in: `lib/hecksagain/runtime/value/coercion.rb line 198`

Type checking logic appears correct but may have bypass path.

## Impact
**Severity:** MEDIUM
- Silent data loss: 12.5 cents becomes 12 cents
- Financial calculations are affected
- No error thrown, so caller doesn't know

## Why Not Fixed
Type checking system is complex. Needs investigation:
1. Which code path bypasses validation?
2. Is implicit to_i conversion happening?
3. Proof that check_numeric_fields() is being called

Cannot safely fix without understanding the bypass.

## Test Evidence
- Test: spec/qa_bugs_spec.rb BUG#8
- Shows float is currently accepted when it shouldn't be
```

---

## When to File vs When to Fix vs When to Skip

### File a GitHub Issue 📝
**ONLY if the bug is CONFIRMED:**
- ✅ Test demonstrates real bug exists
- ✅ Root cause identified (framework boundary found)
- ✅ Not a false positive or user error
- ✅ Requires architectural change OR >30 min to fix

Examples:
- Nested VO invariants silently ignored (architectural)
- State mutation at query boundary (framework gap)

### Fix Immediately ✅
**If you can fix it yourself:**
- Simple invariant change (whitespace check)
- Clear code change required
- Fix is <30 minutes
- All tests pass after fix

Examples:
- `!value.empty?` → `!value.strip.empty?`
- Add `.freeze` to result arrays

### Document in FINDINGS.md, Don't File 📚
**If you're uncertain or code exists but untested:**
- ❌ Type checking exists but no tests confirm it works
- ❌ Overdraft check exists but you're not 100% sure
- ❌ May be false positive or user misunderstanding
- ❌ Needs investigation but not confirmed bug

Mark as: "Investigation Needed" or "PAUSED"
- Create test to document the issue
- Don't file GitHub issue (wastes triage time)
- Next QA session can investigate further

**This session's mistake:** Filed #40, #41, #42 without confirming they were actual bugs

---

## After Filing

1. Update qa/FINDINGS.md with the issue
2. Reference the GitHub issue #
3. Create test in spec/qa_bugs_spec.rb (tagged `qa: true`)
4. Link test to ticket in comment
5. Add to qa/reports/YYYY-MM-DD.md under "Bugs Reported"

---

## Ticket Quality Checklist

- [ ] Title includes BUG#N prefix
- [ ] Problem is stated clearly in first line
- [ ] Reproducible code example provided
- [ ] Root cause investigation included
- [ ] Impact is quantified (HIGH/MEDIUM/LOW)
- [ ] Test case created and referenced
- [ ] Clear reason why it wasn't fixed
- [ ] Fix proposal included (if known)
- [ ] Related issues linked
- [ ] QA session reference included
