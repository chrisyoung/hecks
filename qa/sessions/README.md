# QA Testing Flow Documents

These are **live working documents** you update as you test each domain, tracking:
- What you're testing and why
- Progress through the 8 adversarial categories
- Bugs discovered in real-time
- Fix attempts and investigation results

## File Naming Convention

**One flow per domain per session:**
- `YYYY-MM-DD-[DomainName].md`

Examples:
- `2026-08-11-Pizzas.md`
- `2026-08-11-Banking.md`
- `2026-08-12-Compliance.md`

If testing multiple domains in one session, create a separate flow for each.

## Using These Documents

### During Session
1. Copy `TEMPLATE.md` to `YYYY-MM-DD-[DomainName].md`
2. Update the document as you work through each phase
3. Mark checkboxes as you test
4. Record findings immediately
5. Update progress section with each discovery

### After Session
1. Complete the summary section
2. Document key takeaways
3. Commit the completed flow document
4. Reference it in qa/reports/YYYY-MM-DD.md

## Structure

Each session flow doc has:

**Planning Phase**
- Target domain
- Aggregates to test
- Which categories to apply

**Testing Progress**
- Real-time checkboxes (⬜ NOT RUN, ✅ PASS, ❌ FAIL)
- Individual test cases and results
- Notes on each finding

**Bug Discovery**
- Each bug found documented immediately
- Severity and root cause
- Fix or investigation status

**Session Summary**
- Coverage metrics
- Results
- Key takeaways for next time

## Example

See `2026-08-11-pizzas-banking.md` for a completed session flow.

## Tips

- **Update in real-time** - Don't wait until the end, record findings as you find them
- **Be specific** - "Test case 1: Try to debit more than balance" not "Test debit"
- **Track your thinking** - Notes help you remember why something happened
- **Use checkboxes** - Makes it easy to see what's left to do
- **Commit when done** - The completed flow is part of your QA record

These documents become part of your QA trail, showing exactly what was tested and what was found.
