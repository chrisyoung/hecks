require "set"

module Hecks
  class Runtime
      # Hecks::Runtime::PolicySetup
      #
      # Mixin that subscribes both aggregate-level and domain-level policies
      # to their trigger events on the event bus. Guards against re-entrant
      # policy execution, checks optional condition blocks before firing,
      # and supports async dispatch via an optional async handler.
      #
      #   class Runtime
      #     include PolicySetup
      #   end
      #
      module PolicySetup
        private

        # Dispatches a command triggered by a policy, routing it to the correct
        # aggregate class method or falling back to the command bus.
        #
        # Finds the aggregate that owns the target command, filters the event
        # attributes to only include keys the command accepts, and attempts
        # to call the method directly on the aggregate class. If no matching
        # class method exists, dispatches through the command bus instead.
        #
        # @param command_name [Symbol, String] the name of the command to dispatch
        # @param event_attrs [Hash] attributes extracted from the triggering event,
        #   keyed by parameter name (Symbol keys)
        # @return [Object] the result of the command execution
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
          full_name = Hecks::Utils.underscore(command_name)
          method_name = full_name
          agg_snake.split("_").each_index do |i|
            suffix = agg_snake.split("_").drop(i).join("_")
            stripped = full_name.sub(/_#{suffix}$/, "")
            if stripped != full_name
              method_name = stripped
              break
            end
          end
          method_name = method_name.to_sym

          if agg_class.respond_to?(method_name)
            agg_class.send(method_name, **filtered_attrs)
          else
            @command_bus.dispatch(command_name, **filtered_attrs)
          end
        end

        # Initializes the re-entrancy guard set and subscribes all reactive
        # policies (both aggregate-level and domain-level) to their trigger
        # events on the event bus.
        #
        # Aggregate-level policies are keyed as "AggName.PolicyName";
        # domain-level policies are keyed as "domain.PolicyName".
        #
        # @return [void]
        def setup_policies
          @policies_in_flight = Set.new

          # Subscribe aggregate-level policies
          @domain.aggregates.each do |agg|
            agg.policies.select(&:reactive?).each do |policy|
              subscribe_policy(policy, "#{agg.name}.#{policy.name}")
            end
          end

          # Subscribe domain-level policies
          @domain.policies.select(&:reactive?).each do |policy|
            subscribe_policy(policy, "domain.#{policy.name}")
          end
        end

        # Subscribes a single policy to its trigger event on the event bus.
        #
        # When the event fires, this handler:
        # 1. Checks the re-entrancy guard -- skips if this policy is already in-flight
        # 2. Evaluates the optional condition block -- skips if it returns false
        # 3. Extracts event attributes by inspecting the event's initialize parameters
        # 4. Applies the policy's attribute_map to rename keys, or passes attrs through
        # 5. Merges any static defaults defined on the policy
        # 6. Dispatches the trigger command (async if configured, sync otherwise)
        #
        # Errors during policy execution are caught and logged via +warn+.
        #
        # @param policy [Hecks::DomainModel::Policy] the policy definition from the DSL
        # @param policy_key [String] unique key for re-entrancy tracking
        #   (e.g., "Pizza.AutoConfirm" or "domain.NotifyAdmin")
        # @return [void]
        def subscribe_policy(policy, policy_key)
          @event_bus.subscribe(policy.event_name) do |event|
            if @policies_in_flight.include?(policy_key)
              warn "[Hecks] Skipping re-entrant policy #{policy.name} (already in-flight)"
              next
            end

            begin
              @policies_in_flight.add(policy_key)

              if policy.condition
                next unless policy.condition.call(event)
              end

              event_attrs = {}
              event.class.instance_method(:initialize).parameters.each do |_, name|
                next unless name
                event_attrs[name] = event.send(name) if event.respond_to?(name)
              end

              mapped_attrs = if policy.attribute_map.any?
                policy.attribute_map.each_with_object({}) do |(from, to), h|
                  h[to.to_sym] = event_attrs[from.to_sym] if event_attrs.key?(from.to_sym)
                end
              else
                event_attrs
              end

              # Merge static defaults (overrides mapped values for same key)
              mapped_attrs = mapped_attrs.merge(policy.defaults) if policy.defaults.any?

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
