# Policy Execution Tracing

Debug reactive policy execution by recording every invocation with
the policy name, triggering event, condition result, and timestamp.

## Setup

```ruby
app = Hecks.boot(__dir__)
app.extend(:policy_tracing)
```

## Usage

```ruby
Pizza.create(name: "Margherita")

Hecks.policy_traces
# => [
#   {
#     policy: "AutoReady",
#     event: "CreatedPizza",
#     timestamp: 2026-04-01 12:00:00 UTC,
#     condition_met: true
#   }
# ]
```

## Clearing Traces

```ruby
Hecks.clear_policy_traces
Hecks.policy_traces  # => []
```

## API

| Method | Description |
|--------|-------------|
| `Hecks.policy_traces` | Array of trace hashes (returns a copy) |
| `Hecks.clear_policy_traces` | Reset the trace buffer |
