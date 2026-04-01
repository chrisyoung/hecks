# AI Governance

When a domain declares `world_goals`, the MCP server enforces governance rules
on AI actions. Commands that violate declared goals are refused with a structured
explanation before they execute.

## How It Works

1. The domain declares goals: `world_goals :transparency, :consent, :privacy`
2. An AI agent calls `execute_command` via MCP
3. `GovernanceGuard` runs the domain validator and checks for world-goals violations
4. If violations exist for the specific command, execution is refused with details
5. If no violations, the command proceeds normally

## MCP Tools

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

## Workshop API

Set world goals on a workshop-built domain:

```ruby
ws = Hecks.workshop("Healthcare")
ws.aggregate("Patient") do
  attribute :name, String
  command("UpdatePatient") { attribute :name, String; actor "Doctor" }
end
ws.world_goals(:consent, :privacy)

domain = ws.to_domain
domain.world_goals  # => [:consent, :privacy]
```

## Available Goals

| Goal | Enforces |
|------|----------|
| `:transparency` | Every command must emit at least one event |
| `:consent` | Commands on user-like aggregates must declare an actor |
| `:privacy` | PII must be `visible: false`; PII aggregates need actors |
| `:security` | Command actors must be declared at the domain level |
