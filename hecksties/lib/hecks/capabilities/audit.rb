# Hecks::Capabilities::Audit
#
# Audit capability that wires the Hecks::Audit extension as an opt-in
# hecksagon concern. Follows the capability pattern: detects whether the
# audit extension is already loaded, wires it idempotently, and adds
# command bus middleware for actor/tenant context enrichment.
#
# Usage:
#   Hecks::Capabilities::Audit.apply(runtime)
#
#   # Or via concerns DSL in hecksagon:
#   Hecks.hecksagon do
#     concerns :transparency, :privacy
#   end
#
require_relative "../concerns/mapping"

module Hecks
  module Capabilities
    module Audit
      # Apply the audit capability to a runtime. Loads the audit extension
      # if not already present, subscribes to the event bus, and registers
      # command bus middleware for context enrichment.
      #
      # Idempotent: if Hecks.audit_log already exists, skips wiring.
      #
      # @param runtime [Hecks::Runtime] the runtime to wire audit into
      # @param actor_resolver [Proc, nil] optional proc that returns the actor
      #   string for the current request context
      # @param tenant_resolver [Proc, nil] optional proc that returns the tenant
      #   string for the current request context
      # @return [Hecks::Audit] the audit instance
      def self.apply(runtime, actor_resolver: nil, tenant_resolver: nil)
        return Hecks.instance_variable_get(:@_audit) if Hecks.respond_to?(:audit_log)

        load_extension
        audit = Hecks::Audit.new(runtime.event_bus)
        store_audit(audit)
        register_middleware(runtime, audit, actor_resolver: actor_resolver, tenant_resolver: tenant_resolver)
        audit
      end

      # Check whether the audit capability is already active.
      #
      # @return [Boolean]
      def self.active?
        Hecks.respond_to?(:audit_log)
      end

      private

      # Load the audit extension file if Hecks::Audit is not yet defined.
      #
      # @return [void]
      def self.load_extension
        return if defined?(Hecks::Audit)

        require "hecks/extensions/audit"
      end

      # Store the audit instance on Hecks and expose audit_log.
      #
      # @param audit [Hecks::Audit] the audit instance
      # @return [void]
      def self.store_audit(audit)
        Hecks.instance_variable_set(:@_audit, audit)
        return if Hecks.respond_to?(:audit_log)

        Hecks.define_singleton_method(:audit_log) { @_audit.log }
      end

      # Register command bus middleware that enriches audit entries with
      # actor and tenant context from the current request.
      #
      # @param runtime [Hecks::Runtime] the runtime
      # @param audit [Hecks::Audit] the audit instance
      # @param actor_resolver [Proc, nil] optional actor resolver
      # @param tenant_resolver [Proc, nil] optional tenant resolver
      # @return [void]
      def self.register_middleware(runtime, audit, actor_resolver: nil, tenant_resolver: nil)
        runtime.use(:audit_capability) do |cmd, nxt|
          actor = resolve_actor(actor_resolver)
          tenant = resolve_tenant(tenant_resolver)
          audit.around_command(cmd, nxt, actor: actor, tenant: tenant)
        end
      end

      # Resolve the current actor from the resolver or Hecks.actor.
      #
      # @param resolver [Proc, nil]
      # @return [String, nil]
      def self.resolve_actor(resolver)
        return resolver.call if resolver

        actor = Hecks.respond_to?(:actor) ? Hecks.actor : nil
        actor.respond_to?(:role) ? actor.role : nil
      end

      # Resolve the current tenant from the resolver or Hecks.tenant.
      #
      # @param resolver [Proc, nil]
      # @return [String, nil]
      def self.resolve_tenant(resolver)
        return resolver.call if resolver

        Hecks.respond_to?(:tenant) ? Hecks.tenant : nil
      end

      private_class_method :load_extension, :store_audit, :register_middleware,
                           :resolve_actor, :resolve_tenant
    end
  end
end
