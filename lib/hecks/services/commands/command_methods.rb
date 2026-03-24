# Hecks::Services::Commands::CommandMethods
#
# Wires command classes to repositories and event buses, then creates
# shortcut methods on aggregate classes that delegate to command.call.
#
#   Commands.bind(PizzaClass, pizza_aggregate, bus, repo, defaults)
#   Pizza.create(name: "Margherita")  # delegates to CreatePizza.call(...)
#
#   Commands.bind_shortcuts(PizzaClass, pizza_aggregate) { |cmd| executor }
#   # creates shortcut methods using a custom executor proc
#
module Hecks
  module Services
    module Commands
      module CommandMethods
      def self.bind(klass, aggregate, bus, repo, defaults)
        mod = begin; klass.const_get(:Commands); rescue NameError; nil; end
        return unless mod

        aggregate.commands.each do |cmd|
          cmd_class = begin; mod.const_get(cmd.name); rescue NameError; nil; end
          next unless cmd_class

          # Auto-include mixin if not already included
          cmd_class.include(Hecks::Command) unless cmd_class < Hecks::Command

          # Wire the command to its repository, event bus, handler, and middleware
          cmd_class.repository = repo
          event_bus = bus.respond_to?(:event_bus) ? bus.event_bus : bus
          cmd_class.event_bus = event_bus
          cmd_class.handler = cmd.handler
          cmd_class.guarded_by = cmd.guard_name
          cmd_class.command_bus = bus

          # Set event name from domain IR (convention: CreatePizza -> CreatedPizza)
          event_idx = aggregate.commands.index { |c| c.name == cmd.name }
          event_def = aggregate.events[event_idx] if event_idx
          cmd_class.emits(event_def.name) if event_def && !cmd_class.event_name
        end

        # Create shortcut methods using cmd_class.call as the executor
        bind_shortcuts(klass, aggregate) do |cmd|
          cmd_class = mod.const_get(cmd.name)
          ->(attrs) { cmd_class.call(**attrs).aggregate }
        end
      end

      # Creates class and instance shortcut methods on an aggregate class.
      # Yields each command; the block must return a callable that accepts
      # a keyword hash and returns the result.
      #
      #   bind_shortcuts(Cat, cat_aggregate) do |cmd|
      #     ->(attrs) { playground.execute(cmd.name, **attrs) }
      #   end
      #
      def self.bind_shortcuts(klass, aggregate)
        agg_snake = Hecks::Utils.underscore(aggregate.name)

        aggregate.commands.each do |cmd|
          executor = yield(cmd)
          full_name = Hecks::Utils.underscore(cmd.name)
          method_name = full_name.sub(/_#{agg_snake}$/, "").to_sym

          # Class method: Pizza.create(name: "Margherita")
          klass.define_singleton_method(method_name) do |**attrs|
            executor.call(attrs)
          end

          # Instance method: cat.meow — auto-fills from self's attributes
          cmd_attrs = cmd.attributes
          next if klass.method_defined?(method_name)
          klass.define_method(method_name) do |**overrides|
            filled = {}
            cmd_attrs.each do |ca|
              key = ca.name.to_sym
              if overrides.key?(key)
                filled[key] = overrides[key]
              elsif respond_to?(key)
                filled[key] = send(key)
              end
            end
            executor.call(filled)
          end
        end
      end
      end
    end
  end
end
