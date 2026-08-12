# QA Senior Handbook

**Role:** Fix bugs that junior QA agents discovered but couldn't resolve. Own the fix-path strategy, avoid churn, and document the approach so other agents can follow.

**Non-Goal:** Find bugs. That's the junior agent's job. We fix them.

---

## Philosophy

1. **Fix it or defer it permanently** — half-fixed bugs create tech debt that haunts future sessions
2. **Understand root cause** — a surface fix that doesn't address the architecture is a trap
3. **Avoid churn** — if a fix requires 3 reverts before landing, we're doing it wrong
4. **Document the fix path** — so the next senior engineer doesn't re-investigate the same bug
5. **Test verification first** — every fix must pass the full suite before committing

---

## Decision Tree: Fix or Defer?

When the junior agent hands off a bug:

```
Is it a confirmed bug (test case fails)?
├─ NO → Reject it. Junior agent's job to verify.
└─ YES → Can you fix it in < 4 hours without major refactor?
   ├─ YES → Fix it now (this session)
   └─ NO → Defer it with a permanent record
      ├─ Add to FINDINGS.md with "PAUSED" status
      ├─ Create a GitHub issue (label: architectural)
      └─ Document why in DEFER_LOG.md
```

**Never commit a half-fixed bug.** Either fix it completely, or don't touch it.

---

## Workflow: Fix a Bug

### Phase 1: Verify the Bug (15 min)

1. Read the junior agent's test case
2. Run it locally — confirm it fails
3. Read their diagnosis — do you agree?
4. If NO — reject it back to junior QA, don't spend time
5. If YES → continue

**Output:** A failing test that demonstrates the bug

### Phase 2: Understand Root Cause (30-60 min)

1. **Trace the execution path** — where does the bug manifest?
2. **Read the code** — understand what it's supposed to do
3. **Check git blame** — when was this code written? What was the intent?
4. **Look for similar patterns** — is this bug in multiple places?
5. **Document findings** in SENIOR_SESSION_LOG.md

**Output:** Clear understanding of root cause, not just symptoms

### Phase 3: Design the Fix (15-30 min)

Before writing code:

1. **List all affected call sites** — where else does this code run?
2. **Check for dependencies** — what other code relies on the current (buggy) behavior?
3. **Outline the fix** — what will change? How much code?
4. **Estimate risk** — is this a low-risk local fix or a high-risk structural change?
5. **Plan the test** — how will we verify the fix and prevent regression?

If risk is high:
- Check if it's already deferred in FINDINGS.md → respect that decision
- If not → consider deferring instead of shipping a risky fix

**Output:** A fix outline that other engineers could understand

### Phase 4: Implement (varies)

1. **Write the test first** — the failing test case from Phase 1
2. **Make the fix** — as narrow as possible, no refactoring
3. **Run related tests** — make sure you didn't break neighbors
4. **Commit with context**:
   ```
   Fix Bug #XX: [bug title]
   
   Root cause: [one sentence]
   Affected: [list of files/domains]
   
   Verification:
   - [test case that now passes]
   - [manual verification steps]
   
   GitHub Issue: #XX
   
   Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
   ```
5. **Create a PR** — push your fix branch and open a PR on GitHub
   ```
   git push origin [fix-branch]
   # Open PR on GitHub, link to issue in description
   ```

### Phase 5: Full Verification (30+ min)

**Before pushing, you must:**

1. Run full test suite: `rspec --order random`
2. Run property tests: `bin/fuzz` (if applicable to this domain)
3. Run static checks: `bin/model_check` (if applicable)
4. Re-run the junior agent's test explicitly
5. Manual smoke test in `bin/console` if applicable

If ANY test fails:
- Don't push. Revert.
- Understand why. Is it your fix or a pre-existing issue?
- If pre-existing → document and continue. If your fix → fix it.

**Output:** Green test suite, documented verification

**After verification:**

1. Push the PR: `git push origin [fix-branch]`
2. Open/update PR on GitHub
   - Title: `Fix Bug #XX: [bug title]`
   - Description: Reference GitHub issue: `Fixes #XX` or `Closes #XX`
   - Link commit hash in description
3. Merge if safe (all tests green, narrow fix)
   - Use squash/rebase if applicable
   - Delete branch after merge
4. Close GitHub issue only after PR is merged
   - Add comment with PR link: `Fixed in PR #YYY`
   - Link to commit in FINDINGS.md

### Phase 6: Document (15 min)

1. **Update FINDINGS.md** — mark bug as FIXED with commit hash
2. **Update SENIOR_SESSION_LOG.md** — add fix summary
3. **Close or update GitHub issue** — if one exists
4. **Commit the documentation** separately from the fix (good practice)

**Output:** Future engineers can find the fix and understand the decision

---

## What Constitutes a "Fix"?

✅ **A real fix:**
- Test goes from RED → GREEN
- Full test suite still passes
- Root cause is addressed, not just symptoms
- Decision is documented (why this approach?)
- Manual verification confirms the behavior

❌ **Not a fix:**
- Disabling/skipping the test
- Adding a `.try` or `.present?` to hide the error
- Reverting to "simpler" code that's still wrong
- Fixing it in one place but leaving the bug in 5 others
- "We'll refactor this later"

---

## Checklist Before Every Push

- [ ] Test I'm fixing is now GREEN
- [ ] Full test suite passes: `rspec --order random`
- [ ] No `.skip`, `.pending`, or commented-out tests
- [ ] All affected call sites handled
- [ ] Commit message has root cause explanation
- [ ] FINDINGS.md updated with fix commit hash
- [ ] SENIOR_SESSION_LOG.md has fix summary
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
3. Check if this pattern exists elsewhere

**Examples:** Bugs #4 (whitespace), Pizza name validation

### Pattern 2: State Mutation

**Symptom:** Frozen list is modified, breaking immutability  
**Root Cause:** Code returns mutable array/hash without freezing  
**Fix Pattern:**
1. Locate where the collection is returned
2. Add `.freeze` to array/hash AND each element if nested
3. Test that modifications now raise `FrozenError`

**Examples:** Bugs #1, #5, #10 (list/query/event freezing)

### Pattern 3: Silent Data Loss

**Symptom:** Query returns no results or wrong results  
**Root Cause:** Data type conversion, stringification, or nil coercion  
**Fix Pattern:**
1. Trace the value through the entire pipeline
2. Identify where it changes type or disappears
3. Fix at the source, not symptomatically
4. Test with the exact value that was lost

**Examples:** Bugs #11, #12 (array stringification, empty string → nil)

### Pattern 4: State Violations

**Symptom:** Lifecycle allows invalid transitions or multiple final states  
**Root Cause:** Missing or incorrect `given` guards  
**Fix Pattern:**
1. Map out all valid transitions in the domain
2. Test each invalid transition (should refuse)
3. Add `given` guard if missing or fix it if wrong

### Pattern 5: Architectural Gaps

**Symptom:** Violates DDD principles (anemic model, god object, etc.)  
**Root Cause:** Design decision that shouldn't have been made  
**Fix Pattern:**
- Likely NOT fixable in this session
- Document in FINDINGS.md with PAUSED status
- Add to DEFER_LOG.md with reasoning
- Don't ship a workaround

**Examples:** Bug #2 (nested VO validation architecture)

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
- `git show [commit]` — read the full commit message (often has context)

**Documentation:**
- `qa/FINDINGS.md` — bug registry
- `qa/senior/DEFER_LOG.md` — deferred bugs with reasoning
- `qa/senior/SENIOR_SESSION_LOG.md` — session summary (start fresh each session)

---

## Session Handoff

At the end of your session:

1. **Commit all work** — fixes should be separate commits from documentation
2. **Update SENIOR_SESSION_LOG.md** — summary of what you fixed and why
3. **Update FINDINGS.md** — mark bugs as FIXED or PAUSED
4. **Update DEFER_LOG.md** — add any new deferred bugs
5. **Leave a note** — what's the highest priority for the next session?

**Example session summary:**
```markdown
## Session 2026-08-12

**Bugs Fixed:** #11, #12
**Time:** 4 hours
**Approach:** Traced query pipeline, found stringification of array values

### Bug #11: Array `in:` values silently converted
- **Fix:** Preserve array structure through WhereClause IR, don't stringify
- **Affected:** All adapters (in_memory.rb, postgres.rb, sqlite.rb)
- **Commits:** abc1234, abc1235

### Bug #12: Empty string coerced to nil in `ne:`
- **Fix:** Distinguish between empty string and null in value coercion
- **Affected:** value/coercion.rb, query pipeline
- **Commits:** abc1236

**Deferred:** Bug #2 (nested VO validation)
- Requires recursive validation architecture change
- Added to DEFER_LOG.md

**Next Priority:** Banking comprehensive testing (20-30 bugs waiting)
```

---

## Anti-Patterns (Don't Do These)

❌ **The Band-Aid Fix** — add `.try(:)` to hide the error instead of fixing root cause

❌ **The Shotgun Surgery** — fix one bug by changing 10 files instead of 1

❌ **The False Equivalence** — "this test is like that test, so they must fail for the same reason" (they don't)

❌ **The Premature Optimization** — "let's refactor the whole query system while we're here" (ship the bug fix first)

❌ **The Silent Defer** — remove a test and commit it without updating DEFER_LOG.md

❌ **The Hope and Push** — "the test passed on my machine, so it should pass everywhere" (run the full suite)

---

## How Other Agents Can Use This

If you're a QA agent (junior or future senior) and you see this handbook:

1. **Follow the workflow** — Phases 1-6 are sequential, don't skip
2. **Reference the checklists** — before every push, verify all boxes
3. **Use the decision tree** — Fix or Defer? Let it guide you
4. **Check DEFER_LOG.md** — don't re-investigate bugs we've already decided to defer
5. **Update SENIOR_SESSION_LOG.md** — every session (new file, add to this handbook)
6. **Respect the philosophy** — avoid churn, fix it or defer it, never ship half-fixed bugs

Other senior agents: this handbook is yours to improve. If you find a better pattern, add it. If something doesn't work, remove it.

---

## This Handbook is Living

Update it when:
- You find a pattern that works reliably (add it to "Bug Categories")
- You find a pattern that doesn't work (remove it or flag it)
- You discover a new tool or command that helps (add it)
- You defer a bug for a reason not listed above (update "When to Defer")

**Last updated:** 2026-08-11  
**By:** QA Senior role (Claude)
