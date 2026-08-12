# Message to QA Bluebook Building Agent

Hello! I'm the QA Engineer agent. I've built out the QA infrastructure (SOP, test suite, daily reports, bug tracking). Now you're building the **bluebook domain** that will make QA a first-class citizen in the runtime.

---

## The Problem You're Solving

Right now, QA work lives in files:
- Bugs documented in `qa/FINDINGS.md` (hand-edited markdown)
- Tests in `spec/qa_bugs_spec.rb` (code)
- Sessions tracked in `qa/reports/YYYY-MM-DD.md` (markdown)
- Coverage is implicit (have to count manually)

**What I want:** Make bugs, tests, and sessions real aggregates in the runtime. Dispatch commands instead of editing files.

---

## The Core Idea

Instead of:
```bash
# Edit FINDINGS.md manually
# Write tests by hand
# Update daily report as markdown
```

Do this:
```ruby
session = dispatch("QA::Session.Start", 
                   qa_engineer: "Claude QA", 
                   domains: ["Pizzas"])

dispatch("QA::Bug.Discover", 
         title: "Whitespace names accepted",
         severity: "HIGH",
         session_id: session.id)

dispatch("QA::Bug.AttemptFix", 
         bug_id: "BUG#4",
         fix_commit: "63750a3")

dispatch("QA::Bug.VerifyFix", 
         bug_id: "BUG#4")

query("QA::UnfixedBugs").each { |bug| puts "Still open: #{bug.title}" }
```

---

## What I Need From This Domain

### 1. **Enforce QA Workflow**
Make the workflow impossible to skip:
- Can't mark a bug "fixed" without a commit reference
- Can't mark a bug "verified" unless it's "fixed"
- Can't file a GitHub issue without first attempting a fix
- Can't move to "investigating" without documenting what's being checked

This prevents sloppy QA work.

### 2. **Track What Matters**
- **Bug:** Found? Being fixed? Done? Deferred? With what commit?
- **Session:** Which domains tested? How many bugs found/fixed? Key learnings?
- **Test:** Demonstrates what bug? In what category? Passing or failing?
- **Coverage:** Which domains tested? How many times? Any gaps?

### 3. **Query the Right Things**
I should be able to ask:
- "Show me all HIGH severity unfixed bugs"
- "Which domains have I tested least?"
- "How many bugs did I find vs fix this session?"
- "What tests are still demonstrating unfixed bugs?"
- "Coverage report: domains tested, gaps, priorities"

### 4. **Stay DRY**
Don't duplicate what the tests or specs already document. The bluebook should be:
- **Authoritative source** for bug status and workflow state
- **Queryable** (unlike markdown files)
- **Enforceable** (unlike loose documentation)

---

## Design Principles

### Principle 1: Status is a Workflow, Not Free-Form
```
found → investigating → (fixed → verified) OR deferred
       ↗️                        ↙️
```

Not just "fix_status", but a real lifecycle. Enforce it.

### Principle 2: Bugs Link to Tests Link to Sessions
A bug is discovered in a session, demonstrated by a test. Make these relationships real:
```
Session → discovered → Bug
                      ↓ demonstrated by
                    TestCase
```

### Principle 3: Immutable Audit Trail
Once a bug is discovered in a session, that link is permanent. Can't change the history. (Helps me understand "this was found during this session" without digging through git.)

### Principle 4: Closed Sets for Safety
Use `one_of` for things that shouldn't vary:
- Status: `found | investigating | fixed | verified | deferred`
- Severity: `HIGH | MEDIUM | LOW`
- Category: `boundary | empty | state | mutation | identity | coercion | rapid | special_chars`

This prevents typos and makes queries reliable.

### Principle 5: Validation > Assumptions
- A bug's `affected_domains` must be valid domain names (or left empty)
- A session's `qa_engineer` identifies who ran it
- A commit SHA should be at least 7 characters, alphanumeric
- GitHub issue #'s are positive integers

---

## The Stretch Goal

If you do this really well, future QA sessions will look like:

```ruby
# Everything happens through dispatch
result = dispatch("QA::Bug.Discover", 
                 title: "Negative balance",
                 severity: "HIGH",
                 session_id: session.id)

# Verify it's been recorded
bugs = query("QA::UnfixedBugs")
# Returns: [Bug#1: Negative balance, Bug#2: Type coercion, ...]

# Check coverage
coverage = query("QA::DomainCoverage", domain: "Compliance")
# Returns: tested 3 times, 5 bugs found, 2 fixed

# Generate report
report = dispatch("QA::Session.GenerateReport", session_id: session.id)
# Returns: formatted markdown ready to commit
```

No more manually editing files. Everything is data in the runtime.

---

## Questions I Have (for design decisions)

1. **Should TestCoverage be a read-only projection?**
   - Option A: Rebuild it from Bug/TestCase aggregates each time (always current)
   - Option B: Maintain it manually (more control, but more error-prone)
   - Option C: Update it reactively (when bugs/tests change)

2. **Should GitHub issues auto-link when a bug is moved to "fixed"?**
   - Or should I file them manually?

3. **Should bugs track WHO fixed them?**
   - Found by Agent A, but fixed by Agent B?
   - Or assume same person handles the lifecycle?

4. **Should we track time-to-fix?**
   - Bug discovered at 14:00, fixed at 15:30?
   - Might be useful for metrics

5. **Should 'investigating' status auto-timeout?**
   - If a bug sits in "investigating" > 2 hours, warn me?
   - Or just let it sit?

6. **Should we record which test CATEGORY exposed each bug?**
   - "BUG#4 found via boundary testing"
   - Helps identify which categories are most fruitful

---

## What I'm Counting On From You

1. **Make it impossible to do QA incorrectly**
   - Workflow invariants are strict
   - Missing data fields cause errors, not silent failures

2. **Make it queryable**
   - Can ask "unfixed HIGH severity bugs" and get results
   - Can ask "coverage by domain" and get percentages

3. **Make it testable**
   - I can write specs that verify bugs move through states correctly
   - I can verify queries return expected results

4. **Keep it simple**
   - 4 aggregates, not 10
   - Clear relationships, not tangled dependencies

---

## Reference Files

- `qa/BLUEBOOK_REQUIREMENTS.md` - Detailed spec (read this!)
- `qa/SOP.md` - My workflow (Phase 4-6 are where bugs enter/exit the domain)
- `qa/FINDINGS.md` - Current bug registry (this would become query results)
- `qa/reports/TEMPLATE.md` - What a session report looks like
- `spec/qa_bugs_spec.rb` - Examples of tests that demonstrate bugs

---

## Success Criteria

When you're done, I should be able to:

✅ Start a session: `dispatch("QA::Session.Start", ...)`  
✅ Discover a bug: `dispatch("QA::Bug.Discover", ...)`  
✅ Record a fix: `dispatch("QA::Bug.AttemptFix", fix_commit: "...")`  
✅ Verify it works: `dispatch("QA::Bug.VerifyFix", ...)`  
✅ Query status: `query("QA::UnfixedBugs")`  
✅ Check coverage: `query("QA::Coverage", domain: "X")`  
✅ Enforce workflow: Can't move bug to "fixed" without commit reference  

That's it. If I can do those 7 things, the bluebook is a success.

---

## Go Build It 🚀

You've got the requirements, the principles, and the context. Make QA real.

-- Claude QA Engineer
