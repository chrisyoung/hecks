# QA Bluebook Requirements & Guidance

**For Agent:** Building a Bluebook domain for QA operations based on qa/SOP.md and QA infrastructure

---

## Core Vision

The QA bluebook should make bugs, tests, and sessions **first-class citizens** in the runtime, not just file artifacts. This enables:
- Querying bug status and coverage across domains
- Enforcing QA workflow invariants
- Generating verified reports
- Coordinating multi-agent QA work

---

## Required Aggregates

### 1. **Bug** (identified by bug ID)
Track individual bugs discovered through testing.

**State:**
- `id` - BUG#1, BUG#2, etc.
- `title` - Short description
- `description` - Full problem statement
- `severity` - HIGH/MEDIUM/LOW
- `status` - found → investigating → fixed → verified
- `root_cause` - Where in the code
- `affected_domains` - Which domains it impacts
- `github_issue` - Reference to filed issue (if any)
- `fix_commit` - SHA when fixed (if fixed)
- `discovered_in_session` - Which QA session found it

**Commands:**
- `Discover` - QA engineer finds a bug
- `Investigate` - Start investigating root cause
- `Attempt Fix` - Try to fix the bug
- `File Issue` - File GitHub issue (only after attempted fix)
- `Verify Fix` - Test confirms bug is fixed
- `Defer` - Mark as architectural/deferred

**Invariants:**
- Can only move to `fixed` with a commit reference
- Can only move to `verified` from `fixed`
- `severity` is required
- `status` follows the workflow: found → (investigating) → (fixed → verified) OR deferred

**Queries:**
- `ByStatus` - Find all bugs in a status
- `BySeverity` - Find high-impact bugs
- `ByDomain` - Bugs affecting a domain
- `Unfixed` - Still-open bugs
- `Recent` - Bugs found in this session

---

### 2. **QASession** (identified by date + QA engineer)
Track a QA testing session.

**State:**
- `session_date` - When the session happened
- `qa_engineer` - Who ran it
- `domains_tested` - Which domains were targeted
- `status` - in_progress → completed
- `bugs_found` - Count of bugs discovered
- `bugs_fixed` - Count of bugs fixed this session
- `bugs_filed` - Count of issues filed
- `notes` - Key learnings, gotchas

**Commands:**
- `Start` - Begin a session
- `TestDomain` - Record which domain being tested
- `DiscoverBug` - Link a bug to this session
- `FixBug` - Record a fix completed this session
- `FileBugIssue` - Record an issue filed
- `Complete` - End the session

**Invariants:**
- `bugs_found` >= `bugs_fixed` + `bugs_filed`
- Can't complete until status is `in_progress`
- Must have at least one domain tested

**Queries:**
- `Current` - Today's session
- `ByEngineer` - Sessions by a specific QA engineer
- `Coverage` - Which domains have been tested, how many times

---

### 3. **TestCase** (identified by test name + domain)
Track individual adversarial test cases.

**State:**
- `name` - Test name (e.g., "BUG#7 Overdraft Prevention")
- `domain` - Which domain it tests
- `category` - Which adversarial category (boundary, empty, state, mutation, identity, coercion, rapid, special_chars)
- `status` - passing → failing → pending → fixed
- `location` - File path (spec/qa_bugs_spec.rb)
- `discovered_in_session` - When this test was written
- `linked_bug` - Reference to Bug aggregate (if it demonstrates a bug)
- `expected_behavior` - What should happen
- `actual_behavior` - What currently happens

**Commands:**
- `Create` - Write a new test
- `Execute` - Run the test, record result
- `LinkToBug` - Connect to a Bug aggregate
- `Graduate` - Move test from qa_bugs_spec.rb to main spec file (when bug is fixed)

**Invariants:**
- Must have a category
- Must have expected_behavior documented
- If `status` is failing, must be linked to a Bug
- If `status` is passing, should not be in qa_bugs_spec.rb (graduate to main suite)

**Queries:**
- `ByCategory` - All boundary tests, all empty-value tests, etc.
- `ByDomain` - All tests for Pizzas, Banking, etc.
- `Failing` - Tests demonstrating unfixed bugs
- `ByStatus` - All passing, all failing, all pending

---

### 4. **TestCoverage** (identified by domain)
Aggregate tracking which domains have been tested.

**State:**
- `domain_name` - Which domain
- `categories_tested` - Which adversarial categories applied
- `test_count` - How many tests written
- `bug_count` - Bugs discovered in this domain
- `last_tested_date` - When was it last tested
- `next_priority` - Should this domain be tested again

**Commands:**
- `RecordTesting` - Mark a domain as tested
- `AddTestCase` - Increment test count
- `AddBug` - Increment bug count for this domain

**Invariants:**
- `test_count` >= 0
- `bug_count` <= `test_count`

**Queries:**
- `Untested` - Domains that haven't been tested yet
- `LowCoverage` - Domains with few tests
- `HighBugRate` - Domains with most bugs relative to tests

---

## Cross-Aggregate Relationships

**Bug → TestCase:**
- A Bug can be demonstrated by multiple TestCases
- When a Bug is verified fixed, its TestCases should graduate to main suite

**QASession → Bug:**
- A Session discovers multiple Bugs
- A Bug belongs to exactly one Session (when discovered)

**QASession → TestCase:**
- A Session writes multiple TestCases
- Each TestCase belongs to one Session (when created)

**Bug → QASession:**
- A Bug may be fixed in a different Session than it was found in

**TestCase → TestCoverage:**
- Each TestCase contributes to domain TestCoverage

---

## Helpful Workflow Enforcement

The bluebook should make it **easy to do the right thing**:

1. **Can't file a bug without attempting a fix first**
   ```
   given("fix was attempted before filing") { 
     attempt_fix_recorded || severity >= HIGH
   }
   ```

2. **Can't mark a bug as fixed without a commit**
   ```
   given("fix commit is referenced") { 
     fix_commit.present? if status == "fixed"
   }
   ```

3. **Test cases must have expected behavior documented**
   ```
   invariant("expected behavior is described") {
     expected_behavior.present? && expected_behavior.length > 10
   }
   ```

4. **Can't graduate a test if its bug is still failing**
   ```
   given("linked bug is fixed or test isn't a bug test") {
     linked_bug.nil? || linked_bug.status == "verified"
   }
   ```

---

## Queries That Matter

These queries should be in the bluebook:

**For QA Engineer:**
- "Show me all unfixed bugs I discovered this session"
- "Which domains have I tested the least?"
- "What categories of tests haven't I applied to Compliance domain?"
- "How many bugs have I found and fixed (vs filed)?"

**For Automation:**
- "Generate coverage report" - Which domains tested, how many bugs per domain
- "Show me pending architectural issues" - Bugs marked as deferred
- "List all tests that demonstrate unfixed bugs" - What's in qa_bugs_spec.rb
- "Which bugs are ready to verify?" - Bugs with commit references

---

## Nice-to-Have Features

1. **Metrics & Reporting:**
   - Bug density by domain (bugs / test_count)
   - Session productivity (bugs_found, bugs_fixed ratio)
   - Coverage progress over time

2. **Workflow Triggers:**
   - When a bug is discovered, automatically create a TestCase aggregate
   - When a bug is fixed, suggest moving its TestCase to main suite
   - When a session completes, generate daily report

3. **Validation:**
   - Warn if session has no bugs found (might indicate incomplete testing)
   - Warn if bugs stay in "investigating" > 2 hours
   - Warn if TestCoverage.test_count hasn't increased in a week

4. **Integration:**
   - Port to GitHub - automatically file issues with correct formatting
   - Link to commits - pull commit message when bug is fixed
   - Sync with daily report - qa/reports/YYYY-MM-DD.md is authoritative

---

## Data Integrity Rules

**Must Enforce:**
1. Bug IDs are sequentially assigned (BUG#1, BUG#2, not BUG#999)
2. No two bugs can have the same ID
3. A bug can only be in one domain (or multiple_domains array)
4. Session dates are unique per QA engineer (only one session per day per person)
5. Test categories match the 8 defined categories (from SOP)

**Nice to Enforce:**
1. GitHub issue numbers are only assigned once per bug
2. Commit SHAs are valid (7+ characters, alphanumeric)
3. Session notes are at least 50 characters (meaningful, not empty)

---

## What I (QA Engineer) Will Use This For

1. **Recording bugs without leaving the runtime**
   - `dispatch("QA::Bug.Discover", ...)`
   - Instead of editing FINDINGS.md by hand

2. **Querying status mid-session**
   - "How many bugs have I fixed this session?"
   - Without opening the daily report

3. **Enforcing my own workflow**
   - Can't file an issue without a commit reference
   - Can't move a bug to fixed without attempt documented
   - Can't complete a session without notes

4. **Generating reports**
   - "Show me all bugs by severity"
   - "Coverage report for Banking domain"
   - Instead of manually scanning files

5. **Coordinating with other agents**
   - "Run the QA workflow on Compliance domain, report results via QA::Session"
   - Other agents dispatch into this domain instead of chatting about bugs

---

## Stretch Goal: The Ideal End State

A future session where QA work looks like:

```ruby
session = dispatch("QA::Session.Start", 
                  qa_engineer: "Claude QA Agent",
                  domains: ["Compliance"])

dispatch("QA::Session.TestDomain", 
         session_id: session.id,
         category: "boundary",
         domain: "Compliance")

# ... discover a bug ...

dispatch("QA::Bug.Discover",
         title: "Negative balance allowed",
         severity: "HIGH",
         root_cause: "Missing invariant",
         session_id: session.id)

# ... attempt and complete a fix ...

dispatch("QA::Bug.AttemptFix",
         bug_id: "BUG#7",
         fix_commit: "abc123d")

dispatch("QA::Bug.VerifyFix",
         bug_id: "BUG#7")

# End session with metrics
dispatch("QA::Session.Complete",
         session_id: session.id,
         notes: "Found 3 bugs, fixed 2, filed 1. Ready to test Settlement next.")

# Query results
query = dispatch("QA::TestCoverage.ByDomain",
                 domain: "Compliance")
# Returns: coverage metrics, gaps, next priority
```

That's the vision. Make bugs, sessions, and test cases real entities in the domain, not just files.

---

## Questions for the Agent Building This

1. Should we use `one_of` for Status and Category closed sets?
2. Should TestCoverage be rebuilt from Bug/TestCase aggregates, or maintained manually?
3. Should we validate commit SHAs, or just accept any string?
4. Should bugs auto-expire from "investigating" status after N hours?
5. Should we track who fixed a bug (might be different from who discovered it)?
