# Hecks::DomainConnections
#
# Mixin extended onto generated domain modules (e.g., PizzasDomain) to declare
# what crosses the domain boundary. Two things cross: data (persist_to) and
# events (listens_to / sends_to). Everything outside the boundary is a connection.
#
# Part of the top-level Hecks API. Extended onto domain modules during boot.
#
#   app = Hecks.boot(__dir__) do
#     persist_to :sqlite
#     listens_to DeliveryDomain
#     sends_to :notifications, SendgridAdapter.new
#   end
#
#   # Or after boot:
#   PizzasDomain.persist_to :sqlite
#   PizzasDomain.connections  # => { persist: { type: :sqlite }, ... }
#
module Hecks
  module DomainConnections
    # Declare the persistence adapter for this domain. Supports both unnamed
    # (backward-compatible) and named connections for CQRS read/write separation.
    #
    # @overload persist_to(adapter_type, **options)
    #   Unnamed connection (stored under :default).
    #   @param adapter_type [Symbol] :memory, :sqlite, :postgres, :mysql
    #   @param options [Hash] adapter options (e.g., database: "path.db")
    #
    # @overload persist_to(name, adapter_type, **options)
    #   Named connection for CQRS.
    #   @param name [Symbol] connection name (e.g., :write, :read)
    #   @param adapter_type [Symbol] :memory, :sqlite, :postgres, :mysql
    #   @param options [Hash] adapter options
    def persist_to(name_or_type, type_or_nil = nil, **options)
      if type_or_nil
        name = name_or_type
        type = type_or_nil
      else
        name = :default
        type = name_or_type
      end
      @connections ||= default_connections
      @connections[:persist] ||= {}
      @connections[:persist][name] = { type: type, **options }
    end

    # Declare that this domain listens to events from another domain module.
    # The source must have been booted and expose an event_bus.
    #
    # @param source [Module] another domain module (e.g., DeliveryDomain)
    def listens_to(source)
      @connections ||= default_connections
      @connections[:listens] << source
    end

    # Declare an outbound event channel. All events published in this domain
    # are forwarded to the handler (an adapter object or block).
    #
    # @param name_or_domain [Symbol, Module] channel name or target domain
    # @param adapter [Object, nil] object responding to #call or #publish
    # @param block [Proc] alternative handler block
    def sends_to(name_or_domain, adapter = nil, &block)
      @connections ||= default_connections
      handler = adapter || block
      @connections[:sends] << { name: name_or_domain, handler: handler }
    end

    # Return the current connection configuration hash.
    #
    # @return [Hash] { persist: nil|Hash, listens: Array, sends: Array }
    def connections
      @connections || default_connections
    end

    # Expose the event bus set by Runtime for cross-domain subscriptions.
    #
    # @return [Hecks::EventBus, nil]
    def event_bus
      @event_bus
    end

    private

    def default_connections
      { persist: {}, listens: [], sends: [] }
    end
  end
end
