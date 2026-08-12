# Bug-Fixing Workflow Handbook

**For:** QA agents, senior developers, Level 2 developers, and anyone fixing bugs in the QA queue.

**Goal:** Systematic, reproducible bug-fixing that avoids churn, documents decisions, and makes patterns visible to future agents.

---

## Philosophy

1. **Fix it or defer it permanently** — half-fixed bugs create tech debt
2. **Understand root cause** — surface fixes don't address architecture
3. **Avoid churn** — if a fix requires 3 reverts, we're doing it wrong
4. **Document the fix path** — future agents shouldn't re-investigate
5. **Test verification first** — every fix must pass the full suite before committing
6. **One source of truth** — qa/FINDINGS.md is the authoritative queue, not scattered tickets

---

## Quick Start: What to Do Right Now

**BEFORE YOU START:**
1. Create an isolated worktree: `git worktree add -b qa/session-YYYY-MM-DD ../hecksagain-qa-YYYY-MM-DD`
2. Move into it: `cd ../hecksagain-qa-YYYY-MM-DD`
3. Run tests to establish baseline: `bundle exec rspec --order random 2>&1 | tail -60` 
4. Document pre-existing failures — **do not attempt to fix them**

**If you're seeing this because you need to fix bugs:**

1. Open `qa/FINDINGS.md` — this is your bug queue
2. Pick the next bug marked `NEW` or `UNDER INVESTIGATION`
3. Follow the **6-Phase Workflow** below (Phases 1-6)
4. Update `qa/FINDINGS.md` when done
5. Commit to main with a clear message explaining the fix

**If you're integrating this into daily work (Level 2 workflow):**

- Keep GitHub issues for **escalations only** (bugs you can't fix)
- Fixed bugs: update `qa/FINDINGS.md` + commit to main, no GitHub issue needed
- Unfixable bugs: create GitHub issue + add to `DEFER_LOG.md`
- Run the 1m monitoring loop: `loop 1m keep pulling tickets and trying to solve bugs`

---

## Decision Tree: Fix or Defer?

```
Is it a confirmed bug (test case fails)?
├─ NO → Reject it. Verification is not your job.
└─ YES → Can you fix it in < 4 hours without major refactor?
   ├─ YES → Fix it now (this session, this workflow)
   └─ NO → Defer it permanently
      ├─ Add to qa/FINDINGS.md with "PAUSED" status
      ├─ Create GitHub issue if it blocks other work
      └─ Document why in DEFER_LOG.md
```

**Never commit a half-fixed bug.** Either fix it completely, or don't touch it.

---

## The 6-Phase Workflow

### Phase 1: Verify the Bug (15 min)

1. Read the bug report in qa/FINDINGS.md
2. Read any test case provided
3. Run the test locally — **confirm it fails**
4. Read the diagnosis provided — do you agree?
5. If NO — reject it back to QA, don't spend time
6. If YES — continue to Phase 2

**Output:** A failing test that demonstrates the bug

### Phase 1.5: Understand Testing Methodology (15 min, read once per session)

Read these to understand how to find bugs systematically:
- `qa/SYSTEM_ARCHITECTURE.md` — how commands/queries/events flow through the runtime
- `qa/BUG_FINDING_METHODOLOGY.md` — the 8 systematic testing categories
- `qa/FINDINGS.md` — what's been found, fixed, deferred already

**The 8 Categories (apply to every domain):**
1. **Boundary** — min/max values, edge cases
2. **Empty/Null** — empty strings, nil values, whitespace-only strings
3. **State Violations** — invalid transitions, breaking invariants
4. **Mutation** — verify immutability, frozen collections
5. **Identity** — uniqueness constraints, composite keys
6. **Type Coercion** — wrong types, implicit conversions
7. **Rapid Mutation** — high-volume changes, consistency checks
8. **Special Characters** — unicode, emoji, SQL injection attempts
9. **Fix Verification** — test valid inputs after any fix to ensure it doesn't break them

### Phase 2: Understand Root Cause (30-60 min)

1. **Trace the execution path** — where does the bug manifest?
2. **Read the code** — what's it supposed to do?
3. **Check git blame** — when was this written? What was the intent?
4. **Look for similar patterns** — is this bug in multiple places?
5. **Document findings** in qa/senior/SESSION_*.md

**Output:** Clear understanding of root cause, not just symptoms

### Phase 3: Design the Fix (15-30 min)

Before writing code:

1. **List all affected call sites** — where else does this code run?
2. **Check for dependencies** — what relies on the current (buggy) behavior?
3. **Outline the fix** — what will change? How much code?
4. **Estimate risk** — low-risk local fix or high-risk structural change?
5. **Plan the test** — how will we verify and prevent regression?

If risk is high:
- Check if already deferred in FINDINGS.md → respect that decision
- If not → consider deferring instead of shipping a risky fix

**Output:** A fix outline that other engineers could understand

### Phase 4: Implement (varies)

1. **Write the test first** — the failing test from Phase 1
2. **Make the fix** — as narrow as possible, no refactoring
3. **Run related tests** — make sure you didn't break neighbors
4. **Commit with context:**
   ```
   Fix Bug #XX: [bug title]
   
   Root cause: [one sentence]
   Affected: [list of files/domains]
   
   Verification:
   - [test case that now passes]
   - [manual verification steps if applicable]
   
   Fixes qa/FINDINGS.md Bug #XX
   
   Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
   ```

### Phase 5: Full Verification (30+ min)

**Before pushing, you must:**

1. Run full test suite: `rspec --order random`
2. Run property tests: `bin/fuzz` (if applicable)
3. Run static checks: `bin/model_check` (if applicable)
4. Re-run the bug's test explicitly
5. Manual smoke test in `bin/console` if applicable

If ANY test fails:
- Don't push. Revert.
- Understand why. Is it your fix or pre-existing?
- If pre-existing → document and continue
- If your fix → fix it before pushing

**Output:** Green test suite, documented verification

**After verification:**

1. Push to main: `git push origin HEAD:main`
2. Update `qa/FINDINGS.md` — mark bug as FIXED with commit hash

### Phase 6: Document (15 min)

1. **Update qa/FINDINGS.md** — mark bug FIXED, link commit
2. **Update qa/senior/SESSION_*.md** — add fix summary
3. **Update DEFER_LOG.md** — only if you deferred a bug
4. **Commit the documentation** separately from the fix (good practice)

**Output:** Future engineers can find the fix and understand the decision

---

## What Constitutes a "Fix"?

✅ **A real fix:**
- Test goes from RED → GREEN
- Full test suite still passes
- Root cause addressed, not just symptoms
- Decision documented
- Manual verification confirms behavior

❌ **Not a fix:**
- Disabling/skipping the test
- Adding `.try` or `.present?` to hide the error
- Reverting to "simpler" code that's still wrong
- Fixing one place but leaving bug in 5 others
- "We'll refactor this later"

---

## Daily Workflow (Level 2 Integration)

Use this if you're a Level 2 developer integrating bug-fixing into your daily work.

### Morning (Start of Day)

- Open `qa/FINDINGS.md` — check for new bugs
- Run the 1m monitoring loop (if authorized): `loop 1m keep pulling tickets and trying to solve bugs`
- Check GitHub issues — but remember:
  - GitHub = escalations/unresolved problems only
  - Fixed bugs don't get GitHub issues
  - Investigating bugs don't get GitHub issues

### When You Fix a Bug

1. Follow the 6-Phase Workflow above (15 min to 2 hours depending on complexity)
2. Update `qa/FINDINGS.md` with FIXED status + commit hash
3. Push to main
4. **Do NOT create a GitHub issue** — the fix is done

### When You Can't Fix a Bug

1. Follow Phases 1-3 to understand it deeply
2. Add to `qa/FINDINGS.md` with PAUSED status + reason
3. **Create a GitHub issue** for escalation
4. Add to `qa/senior/DEFER_LOG.md` with full context
5. Leave a comment on the GitHub issue explaining why it's deferred

### GitHub Policy (Important!)

- ✅ Create GitHub issue ONLY if: You cannot fix it (escalation needed)
- ❌ Do NOT create issue if: You fixed it (just update FINDINGS.md)
- ✅ Close GitHub issue ONLY if: You merge a fix PR
- Result: GitHub = escalations/open problems, not completed work

### Before Pushing Any Commit

- [ ] Test I'm fixing is now GREEN
- [ ] Full test suite passes: `rspec --order random`
- [ ] No `.skip`, `.pending`, or commented-out tests
- [ ] All affected call sites handled
- [ ] Commit message has root cause explanation
- [ ] qa/FINDINGS.md updated with fix commit hash
- [ ] No console.log, .byebug, or debug code left
- [ ] Git diff makes sense (no accidental changes)

---

## Bug Categories & Fix Patterns

### Pattern 1: Validation Gaps

**Symptom:** Invalid input accepted (empty string, negative number, nil)  
**Root Cause:** Missing or incomplete validation  
**Fix Pattern:**
1. Add invariant/pattern constraint to `.bluebook`
2. Test with boundary values
3. Check if pattern exists elsewhere

### Pattern 2: State Mutation

**Symptom:** Frozen list is modified, breaking immutability  
**Root Cause:** Code returns mutable array/hash without freezing  
**Fix Pattern:**
1. Locate where collection is returned
2. Add `.freeze` to array/hash AND each element if nested
3. Test that modifications now raise `FrozenError`

### Pattern 3: Silent Data Loss

**Symptom:** Query returns no results or wrong results  
**Root Cause:** Data type conversion, stringification, or nil coercion  
**Fix Pattern:**
1. Trace the value through entire pipeline
2. Identify where it changes type or disappears
3. Fix at the source, not symptomatically
4. Test with the exact value that was lost

### Pattern 4: State Violations

**Symptom:** Lifecycle allows invalid transitions or multiple final states  
**Root Cause:** Missing or incorrect `given` guards  
**Fix Pattern:**
1. Map out all valid transitions
2. Test each invalid transition (should refuse)
3. Add `given` guard if missing or fix if wrong

### Pattern 5: Architectural Gaps

**Symptom:** Violates DDD principles (anemic model, god object, etc.)  
**Root Cause:** Design decision that shouldn't have been made  
**Fix Pattern:**
- Likely NOT fixable in this session
- Document in FINDINGS.md with PAUSED status
- Add to DEFER_LOG.md with reasoning
- Don't ship a workaround

---

## When to Defer a Bug

Add to DEFER_LOG.md if:

1. **Architectural refactor required** — would touch 50+ lines across multiple files
2. **Breaks backward compatibility** — would require migration for existing data
3. **Blocks other work** — someone else is working on it
4. **Needs design review** — domain owner needs to decide the right approach
5. **Pre-existing issue** — root cause is deeper than this bug

**Defer format:**
```markdown
### Bug #XX: [Title]
**Why deferred:** [one sentence reason]
**Blocker on:** [what work depends on this?]
**Next step:** [who needs to make this decision?]
**Estimated effort:** [if someone takes it on]
```

---

## Tools & Commands

**Verification:**
- `rspec spec/ qa/ --order random` — full test suite
- `rspec spec/qa_bugs_spec.rb` — regression tests only
- `bin/fuzz <domain>` — property-based testing
- `bin/model_check <domain>` — static analysis
- `bin/console` — interactive testing

**Investigation:**
- `git log -p -- [file]` — trace code history
- `git blame [file]` — see when/why each line was added
- `git show [commit]` — read the full commit message

**Files:**
- `qa/FINDINGS.md` — bug registry (source of truth)
- `qa/senior/DEFER_LOG.md` — deferred bugs with reasoning
- `qa/senior/SESSION_*.md` — session summaries (new file each session)

---

## Session Handoff

At the end of your session:

1. **Commit all work** — fixes separate from documentation
2. **Update qa/senior/SESSION_*.md** — summary of what you fixed and why
3. **Update qa/FINDINGS.md** — mark bugs as FIXED or PAUSED
4. **Update DEFER_LOG.md** — add any new deferred bugs
5. **Leave a note** — what's the highest priority for the next session?

**Example session summary:**
```markdown
## Session 2026-08-12

**Bugs Fixed:** #11, #12
**Time:** 4 hours
**Approach:** Traced query pipeline, found stringification of array values

### Bug #11: Array `in:` values silently converted
- **Fix:** Preserve array structure through WhereClause IR
- **Affected:** All adapters
- **Commits:** abc1234

### Bug #12: Empty string coerced to nil in `ne:`
- **Fix:** Distinguish between empty string and null
- **Affected:** value/coercion.rb, query pipeline
- **Commits:** abc1235

**Deferred:** Bug #2 (nested VO validation)
- Requires recursive validation architecture change

**Next Priority:** Banking comprehensive testing
```

---

## Anti-Patterns (Don't Do These)

❌ **The Band-Aid Fix** — add `.try(:)` to hide the error instead of fixing root cause

❌ **The Shotgun Surgery** — fix one bug by changing 10 files instead of 1

❌ **The False Equivalence** — assume bugs that look similar fail for the same reason (they don't)

❌ **The Premature Optimization** — refactor the whole system while fixing one bug

❌ **The Silent Defer** — remove a test and commit it without updating DEFER_LOG.md

❌ **The Hope and Push** — "test passed on my machine, so it should pass everywhere"

❌ **Two Source of Truths** — using GitHub issues AND qa/FINDINGS.md inconsistently

---

## How Other Agents Can Use This

If you're a QA agent, junior developer, or future agent and you see this handbook:

1. **Follow the workflow** — Phases 1-6 are sequential, don't skip
2. **Reference the checklists** — before every push, verify all boxes
3. **Use the decision tree** — Fix or Defer? Let it guide you
4. **Check DEFER_LOG.md** — don't re-investigate already-deferred bugs
5. **Update qa/senior/SESSION_*.md** — every session (new file each time)
6. **Respect the philosophy** — avoid churn, fix it or defer it, never ship half-fixed bugs

---

## This Handbook is Living

Update it when:
- You find a pattern that works reliably (add it to "Bug Categories")
- You find a pattern that doesn't work (remove it or flag it)
- You discover a new tool or command that helps (add it)
- You defer a bug for a reason not listed (update "When to Defer")
- You discover a new anti-pattern (add it to "Anti-Patterns")

**Last updated:** 2026-08-12  
**Contributors:** QA Senior role, Level 2 Developer workflow  
**Status:** Unified workflow for all bug fixers
