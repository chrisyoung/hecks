# Hecks::Services::Runtime::ConnectionSetup
#
# Mixin that wires domain connections declared via DomainConnections
# (listens_to and sends_to) onto the event bus at boot time. Also exposes
# the event bus on the domain module for cross-domain subscriptions.
#
# Part of Services::Runtime. Consumed after repositories and policies are set up.
#
#   class Runtime
#     include ConnectionSetup
#   end
#
module Hecks
  module Services
    class Runtime
      module ConnectionSetup
        private

        # Wire listens_to and sends_to connections, and expose the event bus
        # on the domain module so other domains can subscribe to it.
        def setup_connections
          expose_event_bus

          return unless @mod.respond_to?(:connections)

          wire_listens_to(@mod.connections[:listens])
          wire_sends_to(@mod.connections[:sends])
        end

        # Store the event bus on the domain module so other domains
        # can call `SomeDomain.event_bus` to subscribe.
        def expose_event_bus
          bus = @event_bus
          @mod.instance_variable_set(:@event_bus, bus)
        end

        # Subscribe to each source domain's event bus, forwarding all
        # events into our own bus.
        def wire_listens_to(sources)
          return unless sources&.any?

          sources.each do |source|
            unless source.respond_to?(:event_bus) && source.event_bus
              warn "[Hecks] Cannot listen to #{source} — no event bus (not yet booted?)"
              next
            end

            our_bus = @event_bus
            source.event_bus.on_any { |event| our_bus.publish(event) }
          end
        end

        # Subscribe to our event bus and forward all events to each
        # outbound handler (adapter object or callable block).
        def wire_sends_to(targets)
          return unless targets&.any?

          targets.each do |target|
            handler = target[:handler]
            next unless handler

            @event_bus.on_any do |event|
              if handler.respond_to?(:call)
                handler.call(event)
              elsif handler.respond_to?(:publish)
                handler.publish(event)
              end
            end
          end
        end
      end
    end
  end
end
