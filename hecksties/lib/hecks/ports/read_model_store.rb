# Hecks::ReadModelStore
#
# Port for read-side storage in CQRS setups. A ReadModelStore wraps any
# repository adapter and synchronizes it from write-side events. Provides
# +update+, +read+, and +clear+ methods. When HecksCqrs is active, queries
# and scopes are routed here while commands use the write repository.
#
#   store = ReadModelStore.new(adapter: PizzaMemoryRepository.new)
#   store.update(pizza)          # sync an aggregate into the read store
#   store.read.all               # delegates to the underlying adapter
#   store.clear                  # wipe the read store
#
module Hecks
  class ReadModelStore
    # @return [Object] the underlying read-side repository adapter
    attr_reader :adapter

    # Creates a new ReadModelStore backed by the given adapter.
    #
    # @param adapter [Object] a repository adapter instance that responds to
    #   +save+, +find+, +delete+, +all+, +count+, and optionally +query+
    def initialize(adapter:)
      @adapter = adapter
    end

    # Synchronizes an aggregate into the read store by saving it.
    #
    # @param aggregate [Object] the aggregate instance to persist on the read side
    # @return [void]
    def update(aggregate)
      @adapter.save(aggregate)
    end

    # Returns the underlying adapter for direct query access.
    # All read operations (find, all, where, query) go through this.
    #
    # @return [Object] the read-side repository adapter
    def read
      @adapter
    end

    # Wipes all data from the read store.
    #
    # @return [void]
    def clear
      @adapter.clear
    end

    # Delegates +find+ to the underlying adapter for convenience.
    #
    # @param id [String] the aggregate ID
    # @return [Object, nil] the found aggregate or nil
    def find(id)
      @adapter.find(id)
    end

    # Delegates +all+ to the underlying adapter for convenience.
    #
    # @return [Array<Object>] all aggregates in the read store
    def all
      @adapter.all
    end

    # Delegates +count+ to the underlying adapter for convenience.
    #
    # @return [Integer] the number of aggregates in the read store
    def count
      @adapter.count
    end

    # Delegates +delete+ to the underlying adapter for convenience.
    #
    # @param id [String] the aggregate ID
    # @return [void]
    def delete(id)
      @adapter.delete(id)
    end

    # Delegates +save+ to the underlying adapter for convenience.
    #
    # @param aggregate [Object] the aggregate to persist
    # @return [void]
    def save(aggregate)
      @adapter.save(aggregate)
    end

    # Delegates +query+ to the underlying adapter if it responds to it.
    #
    # @param kwargs [Hash] query parameters (conditions, order, limit, etc.)
    # @return [Array<Object>] matching aggregates
    def query(**kwargs)
      @adapter.query(**kwargs)
    end
  end
end
