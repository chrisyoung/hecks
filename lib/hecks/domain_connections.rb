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
    # Declare the persistence adapter for this domain.
    #
    # @param adapter_type [Symbol] :memory (default), :sqlite, :postgres, :mysql
    # @param options [Hash] additional adapter options (e.g., database: "path.db")
    def persist_to(adapter_type, **options)
      @connections ||= default_connections
      @connections[:persist] = { type: adapter_type, **options }
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
    # @return [Hecks::Services::EventBus, nil]
    def event_bus
      @event_bus
    end

    private

    def default_connections
      { persist: nil, listens: [], sends: [] }
    end
  end
end
