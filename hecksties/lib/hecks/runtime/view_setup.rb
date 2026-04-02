module Hecks
  class Runtime
    # Hecks::Runtime::ViewSetup
    #
    # Mixin that wires view projections to the event bus at boot time.
    # Each view becomes a module under the domain namespace with a
    # .current method that returns projected state.
    #
    #   class Runtime
    #     include ViewSetup
    #   end
    #
    module ViewSetup
      private

      # Wires all view (read model) projections defined in the domain DSL.
      #
      # Iterates through +@domain.views+ and delegates to +ViewBinding.bind+
      # for each one, which creates the view module under the domain namespace
      # and subscribes projection procs to the event bus.
      #
      # Returns immediately if the domain does not respond to +views+
      # (backward compatibility with older domain definitions).
      #
      # @return [void]
      # Wires all view (read model) projections defined in the domain DSL.
      #
      # For views that declare +from_stream+, passes the event bus's
      # historical events to ViewBinding so ProjectionRebuilder can replay
      # them before subscribing to live events.
      #
      # @return [void]
      def setup_views
        return unless @domain.respond_to?(:views)

        @domain.views.each do |v|
          store = v.stream ? @event_bus.events.dup : nil
          ViewBinding.bind(v, @event_bus, @mod, event_store: store)
        end
      end
    end
  end
end
