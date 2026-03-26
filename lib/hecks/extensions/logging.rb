# HecksLogging
#
# Connection gem that provides structured logging of command dispatch to $stdout.
# Shows command name, duration in milliseconds, actor, and tenant.
# Registered as command bus middleware via Hecks.register_extension.
#
#   require "hecks_logging"
#   app = Hecks.load(domain)
#   Pizza.create(name: "Margherita")
#   # => [hecks] CreatePizza 0.3ms actor=admin tenant=acme
#
Hecks.describe_extension(:logging,
  description: "Command execution logging",
  config: {},
  wires_to: :command_bus)

Hecks.register_extension(:logging) do |_domain_mod, _domain, runtime|
  runtime.use :logging do |command, next_handler|
    cmd_name = command.class.name.split("::").last
    actor = Hecks.actor&.respond_to?(:role) ? Hecks.actor.role : nil
    tenant = Hecks.tenant
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = next_handler.call
    duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
    parts = ["[hecks]", cmd_name, "#{duration}ms"]
    parts << "actor=#{actor}" if actor
    parts << "tenant=#{tenant}" if tenant
    $stdout.puts parts.join(" ")
    result
  end
end
