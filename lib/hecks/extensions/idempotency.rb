# HecksIdempotency
#
# Idempotency connection for Hecks command bus. Deduplicates retried
# commands by fingerprinting the command class and its attributes. If
# the same fingerprint is seen within a TTL window, returns the cached
# result instead of re-executing. Controlled via ENV:
#
#   HECKS_IDEMPOTENCY_TTL — cache TTL in seconds (default: 300)
#
# Usage:
#
#   require "hecks_idempotency"
#   app.run("CreatePizza", name: "Margherita")  # first call executes
#   app.run("CreatePizza", name: "Margherita")  # second call returns cached
#
Hecks.describe_extension(:idempotency,
  description: "Idempotent command execution via dedup keys",
  config: {},
  wires_to: :command_bus)

Hecks.register_extension(:idempotency) do |_domain_mod, _domain, runtime|
  cache = {}
  ttl = ENV.fetch("HECKS_IDEMPOTENCY_TTL", "300").to_i

  runtime.use :idempotency do |command, next_handler|
    attrs = command.instance_variables.sort.map { |v| [v, command.instance_variable_get(v)] }
    fingerprint = [command.class.name, attrs].hash
    now = Time.now.to_f

    # Clean expired entries
    cache.reject! { |_, v| v[:at] < now - ttl }

    if cache[fingerprint]
      cache[fingerprint][:result]
    else
      result = next_handler.call
      cache[fingerprint] = { result: result, at: now }
      result
    end
  end
end
