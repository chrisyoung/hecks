# HecksRedisStore (Experimental)
#
# Redis persistence extension for Hecks domains. Stores each aggregate
# as a JSON-serialized string under a namespaced key:
#
#   hecks:<domain>:<aggregate>:<id>
#
# Auto-wires when present in the Gemfile. Requires the `redis` gem.
#
# Future gem: hecks_redis_store
#
#   # Gemfile
#   gem "cats_domain"
#   gem "hecks_redis_store"   # auto-wires at boot
#
#   # Or explicitly:
#   app = Hecks.boot(__dir__, adapter: :redis)
#
#   # With custom URL:
#   REDIS_URL=redis://localhost:6379/1 ruby app.rb
#
# STATUS: Experimental — API may change.
#
Hecks.describe_extension(:redis_store,
  description: "Redis persistence (experimental)",
  adapter_type: :driven,
  config: { url: { default: "redis://localhost:6379", desc: "Redis connection URL" } },
  wires_to: :repository)

Hecks.register_extension(:redis_store) do |domain_mod, domain, runtime|
  require "json"
  require "time"

  redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379")

  begin
    require "redis"
    redis = Redis.new(url: redis_url)
  rescue LoadError
    raise "hecks_redis_store requires the `redis` gem. Add `gem 'redis'` to your Gemfile."
  end

  domain_name = domain_mod.name.sub(/Domain\z/, "").downcase

  domain.aggregates.each do |agg|
    repo = Hecks::RedisRepository.new(
      agg.name,
      domain_mod.const_get(agg.name),
      redis: redis,
      namespace: "hecks:#{domain_name}:#{agg.name.downcase}"
    )
    runtime.swap_adapter(agg.name, repo)
  end
end

# Alias for convenience: adapter: :redis
Hecks.extension_registry[:redis] = Hecks.extension_registry[:redis_store]

module Hecks
  # Hecks::RedisRepository
  #
  # Redis-backed persistence for a single aggregate type. Keys follow
  # the pattern namespace:id. Values are JSON strings.
  #
  # Implements the standard Hecks repository interface: find, save,
  # delete, all, count, query, clear.
  #
  #   repo = Hecks::RedisRepository.new("Pizza", PizzaClass,
  #     redis: redis_client, namespace: "hecks:pizzas:pizza")
  #   repo.save(pizza)
  #   repo.find(pizza.id)
  #
  class RedisRepository
    def initialize(aggregate_name, aggregate_class, redis:, namespace:)
      @aggregate_name = aggregate_name
      @aggregate_class = aggregate_class
      @redis = redis
      @namespace = namespace
    end

    def find(id)
      json = @redis.get(key_for(id))
      return nil unless json
      deserialize(JSON.parse(json))
    end

    def save(obj)
      @redis.set(key_for(obj.id), JSON.generate(serialize(obj)))
      obj
    end

    def delete(id)
      @redis.del(key_for(id))
    end

    def all
      keys = scan_keys
      return [] if keys.empty?
      @redis.mget(*keys).compact.map { |json| deserialize(JSON.parse(json)) }
    end

    def count
      scan_keys.size
    end

    def query(conditions: {}, order_key: nil, order_direction: :asc, limit: nil, offset: nil)
      results = all
      results = filter(results, conditions) unless conditions.empty?
      results = sort(results, order_key, order_direction) if order_key
      results = results.drop([offset, 0].max) if offset
      results = results.take([limit, 0].max) if limit
      results
    end

    def clear
      keys = scan_keys
      @redis.del(*keys) unless keys.empty?
    end

    private

    def key_for(id)
      "#{@namespace}:#{id}"
    end

    def scan_keys
      pattern = "#{@namespace}:*"
      keys = []
      cursor = "0"
      loop do
        cursor, batch = @redis.scan(cursor, match: pattern, count: 100)
        keys.concat(batch)
        break if cursor == "0"
      end
      keys
    end

    def filter(results, conditions)
      results.select do |obj|
        conditions.all? do |k, v|
          next false unless obj.respond_to?(k)
          actual = obj.send(k)
          v.is_a?(Hecks::Querying::Operators::Operator) ? v.match?(actual) : actual == v
        end
      end
    end

    def sort(results, order_key, order_direction)
      sorted = results.sort_by do |obj|
        val = obj.respond_to?(order_key) ? obj.send(order_key) : nil
        val.nil? ? "" : val
      end
      order_direction == :desc ? sorted.reverse : sorted
    end

    def serialize(obj)
      h = { "id" => obj.id }
      if obj.class.respond_to?(:hecks_attributes)
        obj.class.hecks_attributes.each do |attr|
          h[attr[:name].to_s] = serialize_value(obj.send(attr[:name]))
        end
      end
      h["created_at"] = obj.created_at&.iso8601 if obj.respond_to?(:created_at)
      h["updated_at"] = obj.updated_at&.iso8601 if obj.respond_to?(:updated_at)
      h
    end

    def serialize_value(val)
      case val
      when Array then val.map { |v| serialize_value(v) }
      when ->(v) { v.class.respond_to?(:hecks_attributes) }
        h = {}
        val.class.hecks_attributes.each { |a| h[a.name.to_s] = serialize_value(val.send(a.name)) }
        h
      else val
      end
    end

    def deserialize(data)
      attrs = {}
      if @aggregate_class.respond_to?(:hecks_attributes)
        @aggregate_class.hecks_attributes.each do |attr|
          attrs[attr[:name]] = data[attr[:name].to_s]
        end
      end
      obj = @aggregate_class.new(id: data["id"], **attrs)
      if data["created_at"]
        obj.instance_variable_set(:@created_at, Time.parse(data["created_at"])) rescue nil
        obj.instance_variable_set(:@updated_at, Time.parse(data["updated_at"])) rescue nil
      end
      obj
    end
  end
end
