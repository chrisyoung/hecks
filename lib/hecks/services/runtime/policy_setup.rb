# Hecks::Services::Runtime::PolicySetup
#
# Mixin that subscribes domain policies to their trigger events on
# the event bus. Guards against re-entrant policy execution and
# supports async dispatch via an optional async handler.
#
#   class Runtime
#     include PolicySetup
#   end
#
require "set"

module Hecks
  module Services
    class Runtime
      module PolicySetup
        private

        def dispatch_policy_command(command_name, event_attrs)
          target_agg = @domain.aggregates.find do |a|
            a.commands.any? { |c| c.name == command_name.to_s }
          end
          return @command_bus.dispatch(command_name, **event_attrs) unless target_agg

          # Filter event attrs to only include keys the target command accepts
          target_cmd = target_agg.commands.find { |c| c.name == command_name.to_s }
          accepted_keys = target_cmd.attributes.map { |a| a.name.to_sym } if target_cmd
          filtered_attrs = accepted_keys ? event_attrs.select { |k, _| accepted_keys.include?(k) } : event_attrs

          agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(target_agg.name))
          agg_snake = Hecks::Utils.underscore(target_agg.name)
          method_name = Hecks::Utils.underscore(command_name).sub(/_#{agg_snake}$/, "").to_sym

          if agg_class.respond_to?(method_name)
            agg_class.send(method_name, **filtered_attrs)
          else
            @command_bus.dispatch(command_name, **filtered_attrs)
          end
        end

        def setup_policies
          @policies_in_flight = Set.new

          @domain.aggregates.each do |agg|
            agg.policies.select(&:reactive?).each do |policy|
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
                  # Apply attribute mapping: rename event keys to command keys
                  mapped_attrs = if policy.attribute_map.any?
                    policy.attribute_map.each_with_object({}) do |(from, to), h|
                      h[to.to_sym] = event_attrs[from.to_sym] if event_attrs.key?(from.to_sym)
                    end
                  else
                    event_attrs
                  end

                  if policy.async && @async_handler
                    @async_handler.call(policy.trigger_command, mapped_attrs)
                  else
                    dispatch_policy_command(policy.trigger_command, mapped_attrs)
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
