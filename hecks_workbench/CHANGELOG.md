# Changelog

## 0.1.0 (Unreleased)

- One-line REPL dot syntax: `Post.title String`, `Post.create`, `Post.create.title String`
- CommandHandle for chained command attribute additions (reference/list types unpacked correctly)
- Lifecycle and transition methods on AggregateHandle
- Terse single-line feedback after every REPL operation
- `serve!` command to start web explorer from REPL
- MCP tools capture and return terse REPL feedback for visible output in Claude Code
- New MCP tools: add_lifecycle, add_transition, add_attribute, extend
- Live `extend` in play mode — apply extensions without rebooting
- `promote("Comments")` — extract aggregate into its own standalone domain file
- Initial release as a standalone component
