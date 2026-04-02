# Live Events (SSE)

Stream domain events in real time via Server-Sent Events.

## SSE Endpoint

Both `DomainServer` and `MultiDomainServer` expose a `GET /_live` endpoint
that returns a `text/event-stream` response. Every domain event published on
the EventBus is broadcast to all connected clients as a JSON line:

```
data: {"type":"CreatedPizza","occurred_at":"2026-04-01T12:00:00+00:00"}
```

### Start the server

```bash
hecks serve pizzas_domain
# Output includes:
#   GET    /_live (SSE)
```

### Connect with curl

```bash
curl -N http://localhost:9292/_live
```

Then in another terminal, create a pizza:

```bash
curl -X POST http://localhost:9292/pizzas \
  -H 'Content-Type: application/json' \
  -d '{"name":"Margherita","style":"Classic"}'
```

The SSE connection will receive:

```
data: {"type":"CreatedPizza","occurred_at":"2026-04-01T12:00:00+00:00"}
```

## JavaScript Client

The web explorer layout includes a built-in `HecksLiveEvents` JavaScript
class that auto-connects on page load.

### Auto-initialized

On any web explorer page, `window.hecksLive` is available automatically.
A green dot indicator in the bottom-right corner shows connection status
and clicking it opens the event panel.

### Custom usage

```javascript
var live = new HecksLiveEvents({
  url: '/_live',       // default
  maxEvents: 100       // default: 50
});

// Listen for events
live.on(function(event) {
  console.log(event.type, event.occurred_at);
});

// Disconnect when done
live.disconnect();
```

### Configuration

| Option      | Default   | Description                         |
|-------------|-----------|-------------------------------------|
| `url`       | `/_live`  | SSE endpoint URL                    |
| `maxEvents` | `50`      | Max events kept in memory           |

## Multi-Domain Server

The `/_live` endpoint is also available on multi-domain servers.
Events from all domains are multiplexed onto the single stream.

## Ruby API (server-side)

The `SseHelpers` mixin provides the SSE infrastructure:

```ruby
class MyServer
  include Hecks::HTTP::SseHelpers

  def initialize
    @sse_clients = []
    @lock = Mutex.new
  end

  def boot
    register_sse_broadcaster(event_bus)
  end

  def handle(req, res)
    if req.path == "/_live"
      handle_sse(req, res)
      return
    end
  end
end
```
