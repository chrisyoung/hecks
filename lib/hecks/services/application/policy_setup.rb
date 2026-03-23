# Hecks::Services::Application::PolicySetup
#
# Mixin that subscribes domain policies to their trigger events on
# the event bus. Guards against re-entrant policy execution and
# supports async dispatch via an optional async handler.
#
#   class Application
#     include PolicySetup
#   end
#
require "set"

module Hecks
  module Services
    class Application
      module PolicySetup
        private

        def setup_policies
          @policies_in_flight = Set.new

          @domain.aggregates.each do |agg|
            agg.policies.each do |policy|
              @event_bus.subscribe(policy.event_name) do |event|
                policy_key = "#{agg.name}.#{policy.name}"

                if @policies_in_flight.include?(policy_key)
                  warn "[Hecks] Skipping re-entrant policy #{policy.name} (already in-flight)"
                  next
                end

                begin
                  @policies_in_flight.add(policy_key)
                  event_attrs = {}
                  event.class.instance_method(:initialize).parameters.each do |_, name|
                    next unless name
                    event_attrs[name] = event.send(name) if event.respond_to?(name)
                  end
                  if policy.async && @async_handler
                    @async_handler.call(policy.trigger_command, event_attrs)
                  else
                    @command_bus.dispatch(policy.trigger_command, **event_attrs)
                  end
                rescue StandardError => e
                  warn "[Hecks] Policy #{policy.name} failed: #{e.message}"
                ensure
                  @policies_in_flight.delete(policy_key)
                end
              end
            end
          end
        end
      end
    end
  end
end
