# Hecks::RedisRepository
#
# Generic Redis-backed repository for Hecks aggregates. Stores each
# aggregate as a JSON string keyed by +prefix:id+. Supports the standard
# repository interface: find, save, delete, all, count, clear, and query.
#
# Usage:
#   repo = Hecks::RedisRepository.new(client: Redis.new, prefix: "hecks:pizzas:pizza")
#   repo.save(pizza)
#   repo.find(pizza.id)
#
module Hecks
  class RedisRepository
    # @param client [Object] a Redis-compatible client (responds to get, set, del, scan)
    # @param prefix [String] key prefix for this aggregate (e.g., "hecks:pizzas:pizza")
    def initialize(client:, prefix:)
      @client = client
      @prefix = prefix
    end

    # Find an aggregate by ID.
    #
    # @param id [String] the aggregate UUID
    # @return [Hash, nil] deserialized aggregate data or nil
    def find(id)
      raw = @client.get(key_for(id))
      raw ? deserialize(raw) : nil
    end

    # Save an aggregate. Serializes to JSON and stores at prefix:id.
    #
    # @param aggregate [Object] must respond to id and to_h or serialize
    # @return [void]
    def save(aggregate)
      data = serialize(aggregate)
      @client.set(key_for(aggregate.id), data)
      aggregate
    end

    # Delete an aggregate by ID.
    #
    # @param id [String] the aggregate UUID
    # @return [void]
    def delete(id)
      @client.del(key_for(id))
    end

    # Return all stored aggregates.
    #
    # @return [Array<Hash>] all deserialized aggregates
    def all
      keys = scan_keys
      return [] if keys.empty?
      keys.map { |k| deserialize(@client.get(k)) }.compact
    end

    # Count stored aggregates.
    #
    # @return [Integer]
    def count
      scan_keys.size
    end

    # Clear all aggregates under this prefix.
    #
    # @return [void]
    def clear
      keys = scan_keys
      keys.each { |k| @client.del(k) } unless keys.empty?
    end

    # Query aggregates by conditions (in-memory filter over all).
    #
    # @param conditions [Hash] attribute conditions
    # @return [Array<Hash>]
    def query(conditions: {}, **_opts)
      results = all
      conditions.each do |k, v|
        results = results.select { |obj| obj.respond_to?(k) ? obj.send(k) == v : obj[k.to_s] == v }
      end
      results
    end

    private

    def key_for(id)
      "#{@prefix}:#{id}"
    end

    def scan_keys
      pattern = "#{@prefix}:*"
      keys = []
      cursor = "0"
      loop do
        cursor, batch = @client.scan(cursor, match: pattern, count: 100)
        keys.concat(batch)
        break if cursor == "0"
      end
      keys
    end

    def serialize(aggregate)
      JSON.generate(Hecks::Utils.serialize_object(aggregate))
    end

    def deserialize(json)
      JSON.parse(json)
    rescue JSON::ParserError
      nil
    end
  end
end
