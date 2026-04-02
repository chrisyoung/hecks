# HecksFailover::MemoryFallback
#
# Minimal in-memory repository used as the failover backing store.
# Implements the same interface as generated memory adapters (find, save,
# delete, all, count, query, clear) using a simple hash keyed by ID.
#
# Usage:
#   fallback = HecksFailover::MemoryFallback.new
#   fallback.save(pizza)
#   fallback.find(pizza.id)  # => pizza
#   fallback.all             # => [pizza]
#
module HecksFailover
  class MemoryFallback
    def initialize
      @store = {}
    end

    # Find an aggregate by ID.
    #
    # @param id [String] the aggregate ID
    # @return [Object, nil] the aggregate or nil
    def find(id)
      @store[id]
    end

    # Save an aggregate, keyed by its ID.
    #
    # @param aggregate [Object] must respond to #id
    # @return [Object] the saved aggregate
    def save(aggregate)
      @store[aggregate.id] = aggregate
    end

    # Delete an aggregate by ID.
    #
    # @param id [String] the aggregate ID
    # @return [Object, nil] the removed aggregate or nil
    def delete(id)
      @store.delete(id)
    end

    # Return all stored aggregates.
    #
    # @return [Array<Object>] all aggregates
    def all
      @store.values
    end

    # Return the count of stored aggregates.
    #
    # @return [Integer] number of aggregates
    def count
      @store.size
    end

    # Query with conditions (simplified -- delegates to filter).
    #
    # @param conditions [Hash] attribute conditions
    # @param order_key [Symbol, nil] sort key
    # @param order_direction [Symbol] :asc or :desc
    # @param limit [Integer, nil] max results
    # @param offset [Integer, nil] skip count
    # @return [Array<Object>] matching aggregates
    def query(conditions: {}, order_key: nil, order_direction: :asc, limit: nil, offset: nil)
      results = @store.values
      unless conditions.empty?
        results = results.select do |obj|
          conditions.all? { |k, v| obj.respond_to?(k) && obj.send(k) == v }
        end
      end
      if order_key
        results = results.sort_by { |obj| obj.respond_to?(order_key) ? obj.send(order_key) : "" }
        results = results.reverse if order_direction == :desc
      end
      results = results.drop(offset) if offset
      results = results.take(limit) if limit
      results
    end

    # Clear all stored aggregates.
    #
    # @return [void]
    def clear
      @store.clear
    end
  end
end
