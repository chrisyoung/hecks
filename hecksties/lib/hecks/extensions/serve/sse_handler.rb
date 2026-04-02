# Hecks::HTTP::SSEHandler
#
# Server-Sent Events handler for streaming domain events to browser clients
# in real time. Manages a thread-safe list of connected SSE clients and
# publishes events from the EventBus as SSE data frames.
#
#   handler = SSEHandler.new
#   handler.subscribe(event_bus)
#   handler.stream(res)  # blocks, streaming events as they arrive
#
require "json"

module Hecks
  module HTTP
    class SSEHandler
      def initialize
        @clients = []
        @lock = Mutex.new
      end

      def subscribe(event_bus)
        event_bus.on_any do |event|
          data = {
            type: Hecks::Utils.const_short_name(event),
            occurred_at: event.respond_to?(:occurred_at) ? event.occurred_at.iso8601 : Time.now.iso8601
          }
          broadcast(data)
        end
      end

      def stream(res)
        res["Content-Type"] = "text/event-stream"
        res["Cache-Control"] = "no-cache"
        res["Connection"] = "keep-alive"
        res["X-Accel-Buffering"] = "no"

        queue = Queue.new
        @lock.synchronize { @clients << queue }

        begin
          res.body = StreamBody.new(queue)
        ensure
          @lock.synchronize { @clients.delete(queue) }
        end
      end

      def client_count
        @lock.synchronize { @clients.size }
      end

      private

      def broadcast(data)
        json = JSON.generate(data)
        frame = "data: #{json}\n\n"
        @lock.synchronize do
          @clients.each { |q| q << frame rescue nil }
        end
      end
    end

    # StreamBody
    #
    # WEBrick-compatible response body that reads SSE frames from a Queue.
    # Implements the +each+ interface WEBrick uses to write chunked responses.
    # The stream ends when a nil sentinel is pushed onto the queue.
    #
    #   body = StreamBody.new(queue)
    #   res.body = body
    #
    class StreamBody
      def initialize(queue)
        @queue = queue
      end

      def each
        yield "retry: 1000\n\n"
        loop do
          frame = @queue.pop
          break if frame.nil?
          yield frame
        end
      end
    end
  end
end
