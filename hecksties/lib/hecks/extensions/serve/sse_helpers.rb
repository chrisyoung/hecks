# Hecks::HTTP::SseHelpers
#
# Mixin providing Server-Sent Events (SSE) support for Hecks HTTP servers.
# Manages a thread-safe list of SSE client connections and provides methods
# to register the EventBus listener, handle incoming SSE requests, and
# broadcast domain events as JSON to all connected clients.
#
# Each event is sent in the standard SSE format:
#   data: {"type":"CreatedPizza","occurred_at":"2026-04-01T12:00:00Z","payload":{...}}
#
# Usage:
#   class MyServer
#     include Hecks::HTTP::SseHelpers
#
#     def boot
#       register_sse_broadcaster(@app.event_bus)
#     end
#
#     def handle(req, res)
#       if req.path == "/_live"
#         handle_sse(req, res)
#         return
#       end
#     end
#   end

module Hecks
  module HTTP
    module SseHelpers
      # Register a global listener on the event bus that broadcasts every
      # published domain event to all connected SSE clients as JSON.
      #
      # @param event_bus [Hecks::EventBus] the event bus to listen on
      # @return [void]
      def register_sse_broadcaster(event_bus)
        event_bus.on_any do |event|
          payload = serialize_event(event)
          broadcast_sse(payload)
        end
      end

      # Handle an incoming SSE request on the /_live endpoint.
      #
      # Sets chunked transfer encoding and text/event-stream content type,
      # then holds the connection open. Sends a heartbeat comment every 15
      # seconds to keep the connection alive. The client is removed from the
      # list when the connection closes.
      #
      # @param _req [WEBrick::HTTPRequest] the incoming request (unused)
      # @param res [WEBrick::HTTPResponse] the response to stream events on
      # @return [void]
      def handle_sse(_req, res)
        res["Content-Type"] = "text/event-stream"
        res["Cache-Control"] = "no-cache"
        res["Connection"] = "keep-alive"
        res["X-Accel-Buffering"] = "no"

        res.chunked = true
        queue = Queue.new
        client = { queue: queue }

        @lock.synchronize { @sse_clients << client }

        res.body = proc do |out|
          loop do
            msg = queue.pop
            break if msg == :close
            out.write(msg)
            out.flush if out.respond_to?(:flush)
          end
        rescue Errno::EPIPE, IOError
          # Client disconnected
        ensure
          @lock.synchronize { @sse_clients.delete(client) }
        end
      end

      private

      # Serialize a domain event into an SSE-formatted string.
      #
      # @param event [Object] the domain event to serialize
      # @return [String] the SSE data line with JSON payload
      def serialize_event(event)
        data = {
          type: Hecks::Utils.const_short_name(event),
          occurred_at: event.occurred_at.iso8601
        }
        "data: #{JSON.generate(data)}\n\n"
      end

      # Broadcast an SSE message string to all connected clients.
      #
      # @param message [String] the formatted SSE message to send
      # @return [void]
      def broadcast_sse(message)
        clients = @lock.synchronize { @sse_clients.dup }
        clients.each { |c| c[:queue] << message }
      end
    end
  end
end
