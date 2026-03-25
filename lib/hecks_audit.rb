# HecksAudit
#
# Connection gem that records an audit trail of every command execution.
# Stores entries with command name, actor, tenant, timestamp, and attributes.
# Registered as command bus middleware via Hecks.register_extension.
#
#   require "hecks_audit"
#   app = Hecks.load(domain)
#   Pizza.create(name: "Margherita")
#   PizzasDomain.audit_log
#   # => [{ command: "CreatePizza", actor: "admin", tenant: "acme", at: ..., attributes: { name: "Margherita" } }]
#
Hecks.register_extension(:audit) do |domain_mod, _domain, runtime|
  domain_mod.instance_variable_set(:@_audit_log, [])
  domain_mod.define_singleton_method(:audit_log) { @_audit_log }

  runtime.use :audit do |command, next_handler|
    result = next_handler.call
    domain_mod.audit_log << {
      command: command.class.name.split("::").last,
      actor: Hecks.actor&.respond_to?(:role) ? Hecks.actor.role : Hecks.actor&.to_s,
      tenant: Hecks.tenant,
      at: Time.now,
      attributes: command.class.ancestors.include?(Hecks::Command) ?
        command.instance_variables.reject { |v| [:@aggregate, :@event].include?(v) }
          .map { |v| [v.to_s.delete("@").to_sym, command.instance_variable_get(v)] }.to_h : {}
    }
    result
  end
end
