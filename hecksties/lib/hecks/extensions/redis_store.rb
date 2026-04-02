# HecksRedisStore
#
# Experimental Redis-backed persistence extension. Provides a
# RedisRepository adapter that stores aggregates as JSON using
# GET/SET/DEL/SCAN. Requires a Redis-compatible client.
#
# Stability: experimental — API may change.
#
# Usage:
#   require "redis"
#   app = Hecks.load(domain)
#   app.extend(:redis_store, client: Redis.new)
#
require_relative "redis_store/redis_repository"

Hecks.describe_extension(:redis_store,
  description: "Redis-backed persistence (experimental)",
  adapter_type: :driven,
  config: {},
  wires_to: :persistence)

Hecks.register_extension(:redis_store) do |_domain_mod, domain, runtime, **opts|
  client = opts[:client]
  unless client
    warn "[hecks] redis_store: no :client provided, skipping"
    next
  end

  domain.aggregates.each do |agg|
    repo = Hecks::RedisRepository.new(
      client: client,
      prefix: "hecks:#{domain.gem_name}:#{agg.name.downcase}"
    )
    runtime.swap_adapter(agg.name, repo)
  end
end
