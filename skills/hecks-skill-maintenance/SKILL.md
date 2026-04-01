---
name: hecks-skill-maintenance
description: 'Keep Hecks custom skills up to date as the codebase evolves. Use after any change that affects DSL syntax, codebase structure, contracts, conventions, or workflows. Checks each skill for staleness and updates it.'
license: MIT
metadata:
  author: hecks
  version: "1.0.0"
---

# Hecks Skill Maintenance

Custom Hecks skills live in `skills/hecks-*/SKILL.md`. They document the codebase, DSL, contracts, and workflows — and they go stale when the code changes. This skill ensures they stay current.

## When to Check

After any change that touches:

| Change | Skills to check |
|--------|----------------|
| DSL keywords, block syntax, attribute types | `hecks-bluebook-dsl` |
| Directory renames, new modules, moved files | `hecks-navigator` |
| New or changed data contracts | `hecks-data-contracts` |
| Pre-commit steps, CI, or commit conventions | `hecks-precommit` |
| Documentation workflow or FEATURES.md format | `hecks-feature-docs` |
| Large rename or restructure completed | `hecks-rename-playbook` (add to past renames table) |

## How to Update

1. Read the affected `skills/hecks-*/SKILL.md`
2. Compare against the current state of the code
3. Edit the skill to reflect reality
4. Bump the `version` in the frontmatter (patch increment)

## What to Watch For

- **New DSL keywords** not listed in `hecks-bluebook-dsl`
- **Moved directories** that make `hecks-navigator` paths wrong
- **New contracts** missing from `hecks-data-contracts`
- **Changed conventions** (e.g., new commit rules, new pre-commit steps) not in `hecks-precommit`
- **Past renames** not recorded in `hecks-rename-playbook`

## Rules

- Skills describe what IS, not what WAS — remove outdated content, don't comment it out
- Keep skills concise — they're reference material, not tutorials
- Don't add speculative content ("we might add X") — only document what exists
- Test that examples in skills actually work before committing updates
