# Hecks::ThreadContextMethods
#
# Thread-local tenant, actor, and trace context.
# Provides accessor pairs and +with_*+ scoping blocks for each context value.
# Extracted from the Hecks module.
#
# Usage:
#   Hecks.trace_id = "abc-123"
#   Hecks.with_trace { |id| puts id }  # auto-generates UUID when nil
#
require "securerandom"

module Hecks
  module ThreadContextMethods
    def tenant
      Thread.current[:hecks_tenant]
    end

    def tenant=(tenant_id)
      Thread.current[:hecks_tenant] = tenant_id&.to_s
    end

    def with_tenant(tenant_id)
      old = Thread.current[:hecks_tenant]
      Thread.current[:hecks_tenant] = tenant_id.to_s
      yield
    ensure
      Thread.current[:hecks_tenant] = old
    end

    def actor
      Thread.current[:hecks_actor]
    end

    def actor=(actor)
      Thread.current[:hecks_actor] = actor
    end

    def with_actor(actor)
      old = Thread.current[:hecks_actor]
      Thread.current[:hecks_actor] = actor
      yield
    ensure
      Thread.current[:hecks_actor] = old
    end

    def current_user
      Thread.current[:hecks_current_user]
    end

    def current_user=(user)
      Thread.current[:hecks_current_user] = user
    end

    def with_user(user)
      old = Thread.current[:hecks_current_user]
      Thread.current[:hecks_current_user] = user
      yield
    ensure
      Thread.current[:hecks_current_user] = old
    end

    def trace_id
      Thread.current[:hecks_trace_id]
    end

    def trace_id=(id)
      Thread.current[:hecks_trace_id] = id&.to_s
    end

    def with_trace(id = nil)
      id ||= SecureRandom.uuid
      old = Thread.current[:hecks_trace_id]
      Thread.current[:hecks_trace_id] = id.to_s
      yield id
    ensure
      Thread.current[:hecks_trace_id] = old
    end
  end
end
