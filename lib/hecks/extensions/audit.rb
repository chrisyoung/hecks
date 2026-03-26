# HecksAudit
#
# Audit trail extension that records an immutable log entry for every
# domain event published on the event bus. Captures the event class name,
# full attribute data, and timestamp. Optionally pairs with command bus
# middleware to enrich entries with command name, actor, and tenant.
#
# Usage:
#   require "hecks_audit"
#
#   app = Hecks.load(domain)
#   audit = HecksAudit.new(app.event_bus)
#
#   # Optional: add command context via middleware
#   app.use(:audit) { |cmd, nxt| audit.around_command(cmd, nxt) }
#
#   Pizza.create(name: "Margherita")
#   audit.log.last[:event_name]  # => "CreatedPizza"
#   audit.log.last[:event_data]  # => { name: "Margherita" }
#
class HecksAudit
  attr_reader :log

  def initialize(event_bus)
    @log = []
    @pending_context = nil
    event_bus.on_any { |event| record(event) }
  end

  # Command bus middleware: sets command context for the next audit entry.
  #
  #   app.use(:audit) { |cmd, nxt| audit.around_command(cmd, nxt) }
  #
  def around_command(command, next_handler, actor: nil, tenant: nil)
    @pending_context = {
      command: command.class.name.split("::").last,
      actor: actor,
      tenant: tenant
    }
    next_handler.call
  end

  # Clear the audit log.
  def clear
    @log.clear
  end

  private

  def record(event)
    entry = {
      command: @pending_context&.dig(:command),
      actor: @pending_context&.dig(:actor),
      tenant: @pending_context&.dig(:tenant),
      timestamp: Time.now,
      event_name: event.class.name.split("::").last,
      event_data: extract_attrs(event)
    }
    @pending_context = nil
    @log << entry
  end

  def extract_attrs(event)
    params = event.class.instance_method(:initialize).parameters
    params.each_with_object({}) do |(_, name), h|
      next unless name
      h[name] = event.send(name) if event.respond_to?(name)
    end
  rescue
    {}
  end
end

# Auto-wire when loaded: subscribe to shared event bus and add middleware.
Hecks.describe_extension(:audit,
  description: "Immutable audit trail for every domain event",
  config: {},
  wires_to: :event_bus)

Hecks.register_extension(:audit) do |_domain_mod, _domain, runtime|
  bus = Hecks.event_bus || runtime.event_bus
  audit = HecksAudit.new(bus)
  Hecks.instance_variable_set(:@_audit, audit)
  Hecks.define_singleton_method(:audit_log) { @_audit.log }
  runtime.use(:audit) do |cmd, nxt|
    audit.around_command(cmd, nxt, actor: Hecks.actor&.respond_to?(:role) ? Hecks.actor.role : nil)
  end
end
