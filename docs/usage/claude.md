# Claude Code Integration

Start file watchers and launch Claude Code in one command:

```bash
$ hecks claude
Watchers started (PID: 12345)
# Claude Code session opens with --dangerously-skip-permissions
```

## What Happens

1. Kills any existing watcher processes
2. Starts `watch-all` in the background — polls every second for `.rb` file changes
3. Launches `claude --dangerously-skip-permissions` with any extra arguments forwarded
4. Cleans up watcher processes when Claude exits

## Watchers

The `hecks_watchers` component provides the watcher classes. Three run on every detected file change:

- **HecksWatchers::FileSize** — warns when files approach the 200-line code limit (triggers at 180)
- **HecksWatchers::CrossRequire** — fails if `require_relative` escapes a component boundary
- **HecksWatchers::Autoloads** — warns when a new class/module file isn't registered in `autoloads.rb`

The `bin/watch-*` scripts are thin wrappers that delegate to these classes.

## PostToolUse Hook

A Claude Code hook reads `tmp/watcher.log` after every Edit, Write, or Bash tool use. This surfaces watcher warnings directly in the Claude session without polling.

## Forwarding Arguments

```bash
$ hecks claude --resume
$ hecks claude -p "fix the failing specs"
```
