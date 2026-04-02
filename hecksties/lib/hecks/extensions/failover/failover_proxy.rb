# Hecks::FailoverProxy
#
# Decorator that wraps a primary repository. On write failure, queues
# the operation in a write log and falls back to an in-memory store.
# On read failure, serves from the fallback. Recovery replays queued
# writes against the primary.
#
# Usage:
#   proxy = FailoverProxy.new(primary: sql_repo)
#   proxy.save(entity)          # tries primary, falls back on error
#   proxy.degraded?             # => true if primary has failed
#   proxy.recover!              # replay write log to primary
#
module Hecks
  class FailoverProxy
    # @return [Boolean] whether the proxy is in degraded (fallback) mode
    def degraded?
      @degraded
    end

    # @return [Integer] number of queued write operations
    def queue_size
      @write_log.size
    end

    # @param primary [Object] the primary repository adapter
    def initialize(primary:)
      @primary = primary
      @fallback = {}
      @write_log = []
      @degraded = false
    end

    def find(id)
      @primary.find(id)
    rescue StandardError
      @degraded = true
      @fallback[id]
    end

    def save(aggregate)
      @primary.save(aggregate)
    rescue StandardError
      @degraded = true
      @fallback[aggregate.id] = aggregate
      @write_log << [:save, aggregate]
      aggregate
    end

    def delete(id)
      @primary.delete(id)
    rescue StandardError
      @degraded = true
      @fallback.delete(id)
      @write_log << [:delete, id]
    end

    def all
      @primary.all
    rescue StandardError
      @degraded = true
      @fallback.values
    end

    def count
      @primary.count
    rescue StandardError
      @degraded = true
      @fallback.size
    end

    def clear
      @primary.clear
    rescue StandardError
      @degraded = true
      @fallback.clear
      @write_log << [:clear]
    end

    def query(conditions: {}, **opts)
      @primary.query(conditions: conditions, **opts)
    rescue StandardError
      @degraded = true
      @fallback.values.select do |obj|
        conditions.all? do |k, v|
          obj.respond_to?(k) && obj.send(k) == v
        end
      end
    end

    # Replay queued writes against the primary adapter.
    # Clears the write log and fallback store on success.
    #
    # @return [Integer] number of replayed operations
    # @raise [StandardError] if primary still fails during replay
    def recover!
      count = @write_log.size
      @write_log.each do |op|
        case op.first
        when :save   then @primary.save(op[1])
        when :delete then @primary.delete(op[1])
        when :clear  then @primary.clear
        end
      end
      @write_log.clear
      @fallback.clear
      @degraded = false
      count
    end

    # Forward unknown methods to the primary.
    def method_missing(method, *args, **kwargs, &block)
      @primary.send(method, *args, **kwargs, &block)
    rescue StandardError
      @degraded = true
      nil
    end

    def respond_to_missing?(method, include_private = false)
      @primary.respond_to?(method, include_private) || super
    end
  end
end
