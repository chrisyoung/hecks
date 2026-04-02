# HecksFailover
#
# Failover extension that decorates repositories with a FailoverProxy.
# When the primary adapter raises an error, writes are queued in a log
# and reads fall back to the memory adapter. Recovery replays the write
# log against the primary.
#
# Usage:
#   app = Hecks.boot(__dir__)
#   app.extend(:failover)
#   Hecks.failover_status      # => :healthy or :degraded
#   Hecks.failover_recover!    # replay queued writes
#
require_relative "failover/failover_proxy"

Hecks.describe_extension(:failover,
  description: "Repository failover with write-log queue and recovery",
  adapter_type: :driven,
  config: {},
  wires_to: :persistence)

Hecks.register_extension(:failover) do |_domain_mod, domain, runtime|
  proxies = []

  domain.aggregates.each do |agg|
    primary = runtime[agg.name]
    proxy = Hecks::FailoverProxy.new(primary: primary)
    proxies << proxy
    runtime.swap_adapter(agg.name, proxy)
  end

  Hecks.instance_variable_set(:@_failover_proxies, proxies)

  Hecks.define_singleton_method(:failover_status) do
    degraded = @_failover_proxies.any?(&:degraded?)
    degraded ? :degraded : :healthy
  end

  Hecks.define_singleton_method(:failover_recover!) do
    @_failover_proxies.each(&:recover!)
  end

  Hecks.define_singleton_method(:failover_queue_size) do
    @_failover_proxies.sum(&:queue_size)
  end
end
