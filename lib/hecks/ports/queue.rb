# Hecks::Queue
#
# Abstract interface for command queues. Commands are dispatched through
# the queue instead of executing inline. The default MemoryQueue processes
# synchronously (same thread); production adapters (Sidekiq, RabbitMQ, SQS)
# process asynchronously. Swap via Hecks.boot { queue :sidekiq }.
#
#   Hecks.queue.enqueue("RegisterModel", name: "GPT-5")
#   handle = Hecks.queue.enqueue("RegisterModel", name: "GPT-5")
#   result = handle.wait  # blocks until complete
#
module Hecks
  module Queue
    # Handle returned from enqueue. Call .wait to block until completion.
    class CommandHandle
      attr_reader :command_name, :attrs, :id

      def initialize(command_name, attrs, executor:)
        @command_name = command_name
        @attrs = attrs
        @id = SecureRandom.uuid
        @executor = executor
        @result = nil
        @completed = false
      end

      def wait(timeout: 30)
        @result = @executor.call unless @completed
        @completed = true
        @result
      end

      def completed?
        @completed
      end

      def result
        @result
      end
    end

    # Default in-memory queue. Processes commands synchronously —
    # enqueue returns a handle, .wait executes immediately.
    # No persistence, no background threads. Swap for production.
    class MemoryQueue
      def initialize(command_resolver: nil)
        @command_resolver = command_resolver
        @handles = []
      end

      def enqueue(command_name, attrs = {})
        executor = -> { execute(command_name, attrs) }
        handle = CommandHandle.new(command_name, attrs, executor: executor)
        @handles << handle
        handle
      end

      def handles
        @handles
      end

      private

      def execute(command_name, attrs)
        if @command_resolver
          @command_resolver.call(command_name, attrs)
        else
          raise Hecks::Error, "No command resolver configured for queue"
        end
      end
    end
  end
end
