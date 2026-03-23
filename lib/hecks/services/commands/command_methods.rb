# Hecks::Services::Commands::CommandMethods
#
# Wires command classes to repositories and event buses, then creates
# shortcut methods on aggregate classes that delegate to command.call.
#
#   Commands.bind(PizzaClass, pizza_aggregate, bus, repo, defaults)
#   Pizza.create(name: "Margherita")  # delegates to CreatePizza.call(...)
#
module Hecks
  module Services
    module Commands
      module CommandMethods
      def self.bind(klass, aggregate, bus, repo, defaults)
        agg_snake = Hecks::Utils.underscore(aggregate.name)
        mod = klass.const_get(:Commands) rescue nil
        return unless mod

        aggregate.commands.each do |cmd|
          cmd_class = mod.const_get(cmd.name) rescue nil
          next unless cmd_class

          # Auto-include mixin if not already included
          cmd_class.include(Hecks::Command) unless cmd_class < Hecks::Command

          # Wire the command to its repository, event bus, handler, and middleware
          cmd_class.repository = repo
          event_bus = bus.respond_to?(:event_bus) ? bus.event_bus : bus
          cmd_class.event_bus = event_bus
          cmd_class.handler = cmd.handler
          cmd_class.command_bus = bus

          # Set event name from domain IR (convention: CreatePizza -> CreatedPizza)
          event_idx = aggregate.commands.index { |c| c.name == cmd.name }
          event_def = aggregate.events[event_idx] if event_idx
          cmd_class.emits(event_def.name) if event_def && !cmd_class.event_name

          # Create shortcut on aggregate: Pizza.create -> CreatePizza.call
          full_name = Hecks::Utils.underscore(cmd.name)
          method_name = full_name.sub(/_#{agg_snake}$/, "").to_sym

          klass.define_singleton_method(method_name) do |**attrs|
            cmd_class.call(**attrs).aggregate
          end
        end
      end
      end
    end
  end
end
