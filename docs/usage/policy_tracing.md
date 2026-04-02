# Policy Tracing

Trace every reactive policy execution with timing, condition results, and action data.

## Setup

```ruby
app = Hecks.boot(__dir__) do
  extend :policy_tracing
end
```

Or apply at runtime:

```ruby
app = Hecks.boot(__dir__)
app.extend(:policy_tracing)
```

## Reading Traces

After commands fire policies, inspect the trace log:

```ruby
Hecks.policy_traces
# => [
#   {
#     policy: "ShipNotification",
#     event: "PlacedOrder",
#     condition_result: true,
#     action: "NotifyWarehouse",
#     duration_ms: 0.12,
#     timestamp: 2026-04-01 12:00:00 -0700
#   }
# ]
```

## Trace Fields

| Field | Type | Description |
|-------|------|-------------|
| `policy` | String | Name of the reactive policy |
| `event` | String | The triggering event class name |
| `condition_result` | Boolean | Whether the policy condition passed |
| `action` | String | The command the policy triggers |
| `duration_ms` | Float | Execution time in milliseconds |
| `timestamp` | Time | When the trace was recorded |

## Example: Conditional Policy

```ruby
Hecks.domain "Orders" do
  aggregate "Order" do
    attribute :total, Float

    command "PlaceOrder" do
      attribute :total, Float
    end

    command "FlagHighValue" do
      attribute :total, Float
    end

    policy "HighValueAlert" do
      on "PlacedOrder"
      trigger "FlagHighValue"
      condition { |event| event.total > 1000 }
    end
  end
end

app = Hecks.boot(__dir__) do
  extend :policy_tracing
end

app.run("PlaceOrder", total: 500.0)
Hecks.policy_traces.last[:condition_result]
# => false (policy skipped, but trace still recorded)

app.run("PlaceOrder", total: 2000.0)
Hecks.policy_traces.last[:condition_result]
# => true (policy fired and traced)
```
