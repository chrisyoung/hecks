# Hecks::Services::Commands::CommandRunner
#
# LEGACY — replaced by CommandBus, which adds middleware support.
# Kept for backward compatibility. New code should use CommandBus instead.
#
# Dispatches commands through the domain. Resolves command and event classes,
# creates events from commands, and publishes them on the event bus.
#
#   runner = CommandRunner.new(domain: domain, repositories: repos, event_bus: bus)
#   runner.run("CreatePizza", name: "Margherita")
#   # => #<PizzasDomain::Pizza::Events::CreatedPizza>
#
module Hecks
  module Services
    module Commands
      class CommandRunner
      def initialize(domain:, repositories:, event_bus:)
        @domain = domain
        @repositories = repositories
        @event_bus = event_bus
        @mod = Object.const_get(domain.module_name + "Domain")
      end

      def run(command_name, **attrs)
        agg_def, cmd_def, event_def = resolve(command_name)

        cmd_class = resolve_command_class(agg_def.name, command_name)
        command = cmd_class.new(**attrs)

        event_class = resolve_event_class(agg_def.name, event_def.name)
        event_attrs = extract_event_attrs(command, event_class)
        event = event_class.new(**event_attrs)

        @event_bus.publish(event)

        event
      end

      private

      def resolve(command_name)
        @domain.aggregates.each do |agg|
          agg.commands.each_with_index do |cmd, i|
            if cmd.name == command_name.to_s
              return [agg, cmd, agg.events[i]]
            end
          end
        end

        available = @domain.aggregates.flat_map { |a| a.commands.map(&:name) }
        raise "Unknown command: #{command_name}. Available: #{available.join(', ')}"
      end

      def resolve_command_class(agg_name, command_name)
        agg_mod = @mod.const_get(agg_name)
        agg_mod::Commands.const_get(command_name)
      end

      def resolve_event_class(agg_name, event_name)
        agg_mod = @mod.const_get(agg_name)
        agg_mod::Events.const_get(event_name)
      end

      def extract_event_attrs(command, event_class)
        event_params = event_class.instance_method(:initialize).parameters.map { |_, n| n }
        attrs = {}
        event_params.each do |param|
          attrs[param] = command.send(param) if command.respond_to?(param)
        end
        attrs
      end
      end
    end
  end
end
