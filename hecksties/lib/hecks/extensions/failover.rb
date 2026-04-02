# HecksFailover
#
# Driven extension that wraps repository adapters with a FailoverProxy
# decorator. When the primary repository raises an error, the proxy
# transparently fails over to an in-memory fallback, logging all writes
# for later recovery. A RecoveryMonitor periodically checks if the
# primary is back and replays the write log.
#
# Usage:
#   require "hecks/extensions/failover"
#
#   app = Hecks.load(domain)
#   # Extension auto-wires -- repos are now wrapped with FailoverProxy
#
#   Hecks.failover_status          # => { mode: :primary, write_log_size: 0 }
#   Hecks.failover_recover!        # => forces immediate recovery attempt
#
require "hecks"
require_relative "failover/failover_proxy"
require_relative "failover/recovery_monitor"

Hecks.describe_extension(:failover,
  description: "Automatic repository failover with write-log recovery",
  adapter_type: :driven,
  config: {},
  wires_to: :repository)

Hecks.register_extension(:failover) do |_domain_mod, domain, runtime|
  proxies = []

  domain.aggregates.each do |agg|
    repo = runtime[agg.name]
    proxy = HecksFailover::FailoverProxy.new(repo)
    proxies << proxy
    runtime.swap_adapter(agg.name, proxy)
  end

  monitor = HecksFailover::RecoveryMonitor.new(proxies)

  Hecks.instance_variable_set(:@_failover_proxies, proxies)
  Hecks.instance_variable_set(:@_failover_monitor, monitor)

  Hecks.define_singleton_method(:failover_status) do
    modes = @_failover_proxies.map(&:mode).uniq
    mode = modes.length == 1 ? modes.first : :mixed
    log_size = @_failover_proxies.sum { |p| p.write_log.size }
    { mode: mode, write_log_size: log_size }
  end

  Hecks.define_singleton_method(:failover_recover!) do
    @_failover_monitor.recover!
  end
end
