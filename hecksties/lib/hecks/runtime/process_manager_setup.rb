# Hecks::Runtime::ProcessManagerSetup
#
# Mixin that wires event-driven saga definitions (those with transitions)
# as ProcessManager instances on the event bus at boot time. Each
# event-driven saga gets a ProcessManager that subscribes to events
# and a start method on the domain module.
#
#   class Runtime
#     include ProcessManagerSetup
#   end
#
module Hecks
  class Runtime
    module ProcessManagerSetup
      include HecksTemplating::NamingHelpers
      private

      # Wires all event-driven sagas as ProcessManager instances.
      # Creates a start_<saga_name> method that initializes a process
      # manager instance and wires event subscriptions on the bus.
      #
      # @return [void]
      def setup_process_managers
        return unless @domain.respond_to?(:sagas)

        event_driven = @domain.sagas.select(&:event_driven?)
        return if event_driven.empty?

        @saga_store ||= SagaStore.new

        event_driven.each do |saga|
          pm = ProcessManager.new(saga, @command_bus, @saga_store, @event_bus)
          pm.wire!
          method_name = :"start_#{domain_snake_name(saga.name)}"

          @mod.define_singleton_method(method_name) do |**attrs|
            pm.start(**attrs)
          end
        end
      end
    end
  end
end
