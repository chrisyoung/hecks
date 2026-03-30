# HecksWorkshop

The interactive layer — a Smalltalk-inspired REPL for domain modeling and exploration.

Provides sketch mode (define domains incrementally) and play mode (run commands, watch events, trigger policies). Includes the AI/MCP extension for exposing domains to language models.

## Sub-areas

- **workshop/** — Workshop, Playground, PlayMode, ConsoleRunner, SystemBrowser, BuildActions, Presenter
- **workshop/handles/** — AggregateHandle (builder methods: attr, command, policy, validation, etc.)
- **extensions/ai/** — MCP server, domain server, aggregate tools, play tools, inspect tools
