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
module Hecks
  class Runtime
    module ViewSetup
      private

      def setup_views
        return unless @domain.respond_to?(:views)

        @domain.views.each do |v|
          ViewBinding.bind(v, @event_bus, @mod)
        end
      end
    end
  end
end
