# Live Events via SSE (HEC-300)

Real-time domain event streaming to the browser using Server-Sent Events.

## SSE Endpoint

```
GET /_live
```

Returns a `text/event-stream` response. Each domain event is broadcast as a JSON data frame:

```
data: {"type":"CreatedPizza","occurred_at":"2026-04-01T12:00:00Z"}
```

## JavaScript Client

The `HecksLiveEvents` class is embedded in the layout and connects automatically:

```javascript
// Auto-connects on page load
HecksLiveEvents.on(function(event) {
  console.log(event.type);       // "CreatedPizza"
  console.log(event.occurred_at); // "2026-04-01T12:00:00Z"
});
```

Features:
- Automatic reconnection on disconnect (3-second retry)
- Toast notification in bottom-right corner showing event type
- Toast fades after 2 seconds

## Server-Side

```ruby
handler = Hecks::HTTP::SSEHandler.new
handler.subscribe(runtime.event_bus)
handler.stream(res)  # blocks, streaming events
handler.client_count # => number of connected clients
```

## Availability

Wired into both `DomainServer` (single domain) and `MultiDomainServer` (multi-domain).
