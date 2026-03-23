# Hecks::Session::Playground::RuntimeResolver
#
# Resolves generated command and event classes at runtime by walking the
# domain model's aggregates and looking up the corresponding constants
# in the compiled gem module.
#
# Mixed into Playground to separate class resolution from execution logic.
#
#   class Playground
#     include RuntimeResolver
#     # provides: resolve_command, resolve_event_for, resolve_domain_command,
#     #           available_commands, collect_policies, check_policies
#   end
#
module Hecks
  class Session
    class Playground
      module RuntimeResolver
        private

        def resolve_command(command_name)
          mod = Object.const_get(@mod_name)

          @domain.aggregates.each do |agg|
            agg_class = mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
            next unless agg_class.const_defined?(:Commands)
            begin
              return agg_class::Commands.const_get(command_name)
            rescue NameError, LoadError
              next
            end
          end

          raise "Unknown command: #{command_name}. Available: #{available_commands.join(', ')}"
        end

        def resolve_event_for(command_name)
          mod = Object.const_get(@mod_name)

          @domain.aggregates.each do |agg|
            agg.commands.each_with_index do |cmd, i|
              if cmd.name == command_name.to_s
                event = agg.events[i]
                agg_class = mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
                return agg_class::Events.const_get(event.name)
              end
            end
          end

          raise "No event mapped for command: #{command_name}"
        end

        def resolve_domain_command(command_name)
          @domain.aggregates.each do |agg|
            agg.commands.each do |cmd|
              return cmd if cmd.name == command_name.to_s
            end
          end
          nil
        end

        def available_commands
          @domain.aggregates.flat_map { |a| a.commands.map(&:name) }
        end

        def collect_policies
          @domain.aggregates.flat_map(&:policies)
        end

        def check_policies(event)
          event_name = event.class.name.split("::").last
          @policies.select { |p| p.event_name == event_name }
        end
      end
    end
  end
end
