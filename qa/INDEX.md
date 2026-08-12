# QA Documentation Index

Quick reference for all QA guides and scripts.

## 📚 Guides

### [SOP.md](SOP.md) - **START HERE**
Standard operating procedure for QA engineers.
- 7-phase workflow for systematic testing
- How to discover bugs (8 adversarial categories)
- How to file GitHub issues
- When to fix vs. defer
- Pre-push verification checklist
- **Read this first if you're doing QA work**

### [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
Understanding how hecksagain works internally.
- 15+ directories and their responsibilities
- Dispatch pipeline (command → mutation → event → save)
- Query pipeline
- Critical files for bug hunting
- **Read this first** to understand the system

### [BUG_FINDING_METHODOLOGY.md](BUG_FINDING_METHODOLOGY.md)
How to systematically find bugs in any domain.
- 8 categories of adversarial testing
- Examples for each category
- How I found 3 bugs (2 unfixable, 1 fixed)
- Apply to new domains

### [PROJECTIONS_AND_RUST.md](PROJECTIONS_AND_RUST.md)
Rust runtime and production deployment.
- Pizzas is LIVE on AWS Lambda
- How bluebooks compile to Rust
- Parity testing between Ruby and Rust
- Known issues in Stage 5 parser

### [FINDINGS.md](FINDINGS.md)
Archive of bugs found via QA testing.
- Fixed bugs (list mutability)
- Known unfixable issues (nested VO invariants)
- Test coverage by domain

### [README.md](README.md)
Quick start guide.
- How to run each script
- What each test discovers
- Common tasks

---

## 🔧 Scripts

### [qa_runner.rb](qa_runner.rb)
Automated corpus structure validator.
```bash
ruby qa/qa_runner.rb --verbose
```
- Validates all spec/corpus/*.json files
- Checks step structure
- Reports pass/fail summary

### [qa_adversarial_fixed.rb](qa_adversarial_fixed.rb)
Comprehensive adversarial test suite.
```bash
rspec qa/qa_adversarial_fixed.rb --format progress
```
- Tests 8 categories of edge cases
- Can test any domain
- Finds boundary violations, state corruption, etc.

---

## 🚀 Quick Start

1. **Learn the system**
   ```bash
   cat qa/SYSTEM_ARCHITECTURE.md | less
   ```

2. **Understand bug-finding approach**
   ```bash
   cat qa/BUG_FINDING_METHODOLOGY.md | less
   ```

3. **Run corpus validation**
   ```bash
   ruby qa/qa_runner.rb
   ```

4. **Run adversarial tests**
   ```bash
   rspec qa/qa_adversarial_fixed.rb --format progress
   ```

5. **Check what bugs were found**
   ```bash
   cat qa/FINDINGS.md
   ```

---

## 🧪 Test Verification Workflow

### Local Development (Fast)
```bash
# During development - excludes slow io: true tests
rspec spec/ qa/
```

### Pre-Push Verification (Required)
```bash
# ALWAYS run full test suite before pushing
rspec --order random

# Or use parallel testing (same as CI)
parallel_test spec/
```

**Important:** The pre-push hook enforces this. Full suite includes all tests, including slow I/O tests. Don't skip this step!

### CI Verification (Automatic)
When you push, the pre-push hook runs the full test suite. If you've already verified locally, you're good to go. CI will run again as a final gate.

**Never submit a fix that doesn't pass the full test suite!**

---

## 📊 Bugs Found So Far (2026-08-11)

### ✅ Fixed (4)
- List attributes not frozen (state mutation vulnerability)
  - **Commit:** 8baa725
  - **Impact:** HIGH
  
- Event/reaction/saga logs not frozen (audit trail mutation)
  - **Commit:** e3b110f
  - **Impact:** HIGH
  
- Whitespace-only strings accepted as names
  - **Commit:** 63750a3
  - **Impact:** MEDIUM
  
- Query result rows mutable (data corruption risk)
  - **Commit:** 63750a3
  - **Impact:** HIGH

### 🟡 Known Issues (Require Architecture Changes)
- Nested value object invariants not validated
  - **Impact:** HIGH
  - **Domains affected:** Any with nested VOs
  - **Fix complexity:** Medium

- Invalid closed-set values accepted (cascades from above)
  - **Impact:** HIGH
  - **Status:** Blocked on above issue

---

## 🔍 Testing Entry Points

- **Unit tests:** `spec/*_spec.rb` (individual domains)
- **Corpus tests:** `spec/corpus_spec.rb` (domain loading)
- **Parity tests:** `spec/parser_parity_spec.rb` (Ruby vs Rust)
- **Adversarial tests:** `qa/qa_adversarial_fixed.rb` (edge cases)

---

## 📝 Update Policy

Keep these docs current when:
- A bug is fixed → add to FINDINGS.md
- Architecture changes → update SYSTEM_ARCHITECTURE.md
- New test patterns → update BUG_FINDING_METHODOLOGY.md
- Rust status changes → update PROJECTIONS_AND_RUST.md

**These are living documents** - update immediately after changes.

---

## 🤝 Contributing

To add new QA work:
1. Choose an untested domain (Compliance, Settlement, etc.)
2. Run `rspec qa/qa_adversarial_fixed.rb -k "DomainName"`
3. Document findings in qa/FINDINGS.md
4. Fix bugs or note architectural gaps
5. Keep qa/SYSTEM_ARCHITECTURE.md updated with new learnings
