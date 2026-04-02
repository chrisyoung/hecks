# HecksFailover::FailoverProxy
#
# Repository decorator that wraps a primary repository and falls back to
# an in-memory store when the primary raises errors. All writes during
# failover mode are recorded in a write log for later replay. The proxy
# exposes @mode (:primary or :failover) and @write_log for introspection.
#
# Usage:
#   proxy = HecksFailover::FailoverProxy.new(sql_repo)
#   proxy.save(pizza)          # delegates to sql_repo
#   # sql_repo goes down...
#   proxy.save(pizza)          # transparently uses fallback
#   proxy.failed_over?         # => true
#   proxy.write_log            # => [{ op: :save, args: [pizza], at: Time }]
#   proxy.recover!(sql_repo)   # replays write log, switches back to primary
#
require_relative "memory_fallback"

module HecksFailover
  class FailoverProxy
    attr_reader :mode, :write_log

    # Create a failover proxy wrapping a primary repository.
    #
    # @param primary [Object] the primary repository to delegate to;
    #   must respond to find, save, delete, all, count, query, clear
    # @return [FailoverProxy] proxy in :primary mode
    def initialize(primary)
      @primary = primary
      @fallback = build_fallback
      @mode = :primary
      @write_log = []
    end

    # Whether the proxy is currently in failover mode.
    #
    # @return [Boolean] true if operating against the fallback store
    def failed_over?
      @mode == :failover
    end

    # Attempt recovery: replay the write log against the primary.
    #
    # Tests the primary with a count call. If it succeeds, replays all
    # logged writes in order, then switches back to :primary mode and
    # clears the write log. If the primary is still down, stays in
    # failover mode.
    #
    # @return [Boolean] true if recovery succeeded
    def recover!
      @primary.count
      @write_log.each { |entry| @primary.send(entry[:op], *entry[:args]) }
      @write_log.clear
      @mode = :primary
      true
    rescue StandardError
      false
    end

    def find(id)
      delegate_read(:find, id)
    end

    def save(aggregate)
      delegate_write(:save, aggregate)
    end

    def delete(id)
      delegate_write(:delete, id)
    end

    def all
      delegate_read(:all)
    end

    def count
      delegate_read(:count)
    end

    def query(**kwargs)
      delegate_read_kw(:query, **kwargs)
    end

    def clear
      delegate_write(:clear)
    end

    private

    # Delegate a read operation. On failure, switch to failover.
    #
    # @param method [Symbol] the method name to call
    # @param args [Array] positional arguments
    # @return [Object] the result from primary or fallback
    def delegate_read(method, *args)
      target = @mode == :primary ? @primary : @fallback
      target.send(method, *args)
    rescue StandardError => e
      switch_to_failover! if @mode == :primary
      @fallback.send(method, *args)
    end

    # Delegate a read with keyword arguments.
    #
    # @param method [Symbol] the method name to call
    # @param kwargs [Hash] keyword arguments
    # @return [Object] the result from primary or fallback
    def delegate_read_kw(method, **kwargs)
      target = @mode == :primary ? @primary : @fallback
      target.send(method, **kwargs)
    rescue StandardError => e
      switch_to_failover! if @mode == :primary
      @fallback.send(method, **kwargs)
    end

    # Delegate a write operation. On failure, switch to failover and log.
    #
    # @param method [Symbol] the method name to call
    # @param args [Array] positional arguments
    # @return [Object] the result from primary or fallback
    def delegate_write(method, *args)
      if @mode == :primary
        begin
          return @primary.send(method, *args)
        rescue StandardError
          switch_to_failover!
        end
      end
      result = @fallback.send(method, *args)
      @write_log << { op: method, args: args, at: Time.now }
      result
    end

    # Switch to failover mode, copying primary data to fallback.
    #
    # @return [void]
    def switch_to_failover!
      @mode = :failover
      copy_to_fallback
    end

    # Copy all records from primary to fallback (best effort).
    #
    # @return [void]
    def copy_to_fallback
      @primary.all.each { |agg| @fallback.save(agg) }
    rescue StandardError
      # primary may be completely unreachable
    end

    # Build a simple in-memory fallback store.
    #
    # @return [MemoryFallback] a hash-backed repository
    def build_fallback
      MemoryFallback.new
    end
  end
end
