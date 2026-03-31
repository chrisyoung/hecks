# HecksLive — Real-Time Domain Events

Domain events stream to connected browsers automatically. No custom JavaScript.

## How It Works

1. A command fires (e.g. `Pizza.create`)
2. The event bus publishes a domain event (`CreatedPizza`)
3. HecksLive broadcasts via `Turbo::StreamsChannel`
4. Turbo prepends the event into `#event-feed` on all connected clients

## Rails Setup

Run the generator (included in `active_hecks:init`):

```bash
rails generate active_hecks:live
```

Or add to your layout manually:

```erb
<%= turbo_stream_from "hecks_live_events" %>
<div id="event-feed"></div>
```

Events auto-prepend into `#event-feed`. Use `data-turbo-permanent` to keep
the feed across page navigations:

```erb
<div id="hecks-live" data-turbo-permanent>
  <%= turbo_stream_from "hecks_live_events" %>
  <div id="event-feed"></div>
</div>
```

## Without Rails

Events print to stdout:

```
  [live] CreatedPizza name: Margherita, description: Classic
  [live] AddedTopping pizza_id: abc-123, topping: Mozzarella
```

## Custom Channels

Subscribe to specific events with a `HecksLive::Channel` subclass:

```ruby
class PizzaChannel < HecksLive::Channel
  subscribe_to "CreatedPizza", "AddedTopping"

  def on_event(event)
    data = event_data(event)
    broadcast(data, stream: "pizza_updates")
  end
end
```

Wire it to the event bus:

```ruby
PizzaChannel.wire(event_bus)
# or wire all Channel subclasses at once:
HecksLive.wire_all(event_bus)
```
