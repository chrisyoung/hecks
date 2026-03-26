---
name: Always respond to watcher output
description: When pre-commit hook or PostToolUse watchers report warnings, always address them before moving on
type: feedback
---

Always respond to watcher/hook output from pre-commit or PostToolUse hooks. When watchers report missing specs, doc reminders, file size warnings, or any other issue, fix them immediately before continuing to the next task.

**Why:** The watchers exist to catch quality issues. Ignoring their output defeats their purpose and lets problems accumulate.

**How to apply:** After every commit attempt, read the full hook output. If any watcher reports an issue (missing specs, missing changelog entries, file size warnings, etc.), fix it before moving on. Advisory warnings are still actionable.
