# AI Governance

When a domain declares `world_goals`, Hecks enforces governance rules on command
execution. Commands that violate declared goals are refused with a structured
explanation before they execute.

Governance is a general-purpose layer -- it works from any entry point: CLI,
HTTP, REPL, or MCP. The `GovernanceGuard` accepts a domain object directly,
so any code that has access to a domain can enforce governance.

## How It Works

1. The domain declares goals: `world_goals :transparency, :consent, :privacy`
2. Any entry point creates a guard: `Hecks::GovernanceGuard.new(domain)`
3. The guard runs the domain validator and checks for world-goals violations
4. If violations exist for the specific command, execution is refused with details
5. If no violations, the command proceeds normally

## Programmatic Usage

```ruby
# From a workshop (REPL, scripts, tests)
ws = Hecks.workshop("Healthcare")
ws.aggregate("Patient") do
  attribute :name, String
  command("UpdatePatient") { attribute :name, String }
end
ws.world_goals(:consent, :privacy)

domain = ws.to_domain
guard  = Hecks::GovernanceGuard.new(domain)
result = guard.check("UpdatePatient")

result[:allowed]    # => false
result[:violations] # => ["Consent: Patient#UpdatePatient ..."]
result[:goals]      # => [:consent, :privacy]
```

```ruby
# From a booted app (CLI, HTTP, Rails)
domain = Hecks.boot(__dir__)
guard  = Hecks::GovernanceGuard.new(domain)
result = guard.check("TransferFunds")

unless result[:allowed]
  puts "Blocked: #{result[:violations].join(', ')}"
end
```

## MCP Tools

The MCP server wraps the guard in two convenience tools for AI agents.

### `explain_governance`

Lists the active world goals and their constraints. Call this first to understand
what rules are in effect.

```json
// Request
{ "tool": "explain_governance" }

// Response (goals declared)
{
  "goals": ["transparency", "consent"],
  "constraints": [
    { "goal": "transparency", "description": "Every command must emit at least one domain event. Silent mutations are not allowed." },
    { "goal": "consent", "description": "Commands on user-like aggregates must declare an actor. No anonymous actions on personal data." }
  ]
}

// Response (no goals)
{ "goals": [], "message": "No world goals declared. All actions are allowed." }
```

### `check_governance`

Pre-check a command before executing it. Returns whether it would be allowed.

```json
// Request
{ "tool": "check_governance", "args": { "command": "DeleteRecord" } }

// Response (blocked)
{
  "allowed": false,
  "violations": ["Transparency: Record#DeleteRecord emits no events. Commands must emit events so changes are observable."],
  "goals": ["transparency"]
}

// Response (allowed)
{ "allowed": true, "violations": [], "goals": ["transparency"] }
```

### `execute_command` (governance-gated)

When governance is active, `execute_command` automatically checks before running.
If violations are found, it returns a refusal instead of executing:

```json
// Refused execution
{
  "refused": true,
  "command": "DeleteRecord",
  "violations": ["Transparency: Record#DeleteRecord emits no events."],
  "goals": ["transparency"]
}
```

## Available Goals

| Goal | Enforces |
|------|----------|
| `:transparency` | Every command must emit at least one event |
| `:consent` | Commands on user-like aggregates must declare an actor |
| `:privacy` | PII must be `visible: false`; PII aggregates need actors |
| `:security` | Command actors must be declared at the domain level |
