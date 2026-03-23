# Hecks::Services::Commands::CommandBus
#
# Dispatches commands through a middleware pipeline. Each middleware
# wraps the next, like Rack middleware for commands.
#
#   bus = CommandBus.new(domain: domain, event_bus: event_bus)
#
#   bus.use :logging do |command, next_handler|
#     puts "Dispatching #{command.class.name}"
#     result = next_handler.call
#     puts "Done"
#     result
#   end
#
#   bus.dispatch("CreatePizza", name: "Margherita")
#
module Hecks
  module Services
    module Commands
      class CommandBus
      attr_reader :middleware

      def initialize(domain:, event_bus:)
        @domain = domain
        @event_bus = event_bus
        @mod = Object.const_get(domain.module_name + "Domain")
        @middleware = []
      end

      # Register middleware. Accepts a name and a block, or a middleware object.
      #
      #   bus.use :logging do |command, next_handler|
      #     result = next_handler.call
      #     result
      #   end
      #
      #   bus.use MyMiddleware.new
      #
      def use(name_or_middleware = nil, &block)
        if block
          @middleware << { name: name_or_middleware, handler: block }
        else
          @middleware << { name: name_or_middleware.class.name, handler: name_or_middleware }
        end
      end

      # Dispatch a command by name through the middleware stack.
      # Returns the event.
      def dispatch(command_name, **attrs)
        ctx, agg_def, cmd_def, event_def = resolve(command_name)

        cmd_class = resolve_command_class(ctx, agg_def.name, command_name)
        command = cmd_class.new(**attrs)

        # Build the innermost handler — creates and publishes the event
        event_bus = @event_bus
        inner = -> {
          event_class = resolve_event_class(ctx, agg_def.name, event_def.name)
          event_attrs = extract_event_attrs(command, event_class)
          event = event_class.new(**event_attrs)
          event_bus.publish(event)
          event
        }

        # Wrap middleware around the inner handler, outermost first
        chain = @middleware.reverse.reduce(inner) do |next_handler, mw|
          handler = mw[:handler]
          if handler.is_a?(Proc)
            -> { handler.call(command, next_handler) }
          else
            -> { handler.call(command, next_handler) }
          end
        end

        chain.call
      end

      private

      def resolve(command_name)
        @domain.contexts.each do |ctx|
          ctx.aggregates.each do |agg|
            agg.commands.each_with_index do |cmd, i|
              return [ctx, agg, cmd, agg.events[i]] if cmd.name == command_name.to_s
            end
          end
        end

        available = @domain.aggregates.flat_map { |a| a.commands.map(&:name) }
        raise "Unknown command: #{command_name}. Available: #{available.join(', ')}"
      end

      def resolve_command_class(ctx, agg_name, command_name)
        agg_mod = resolve_aggregate_module(ctx, agg_name)
        agg_mod::Commands.const_get(command_name)
      end

      def resolve_event_class(ctx, agg_name, event_name)
        agg_mod = resolve_aggregate_module(ctx, agg_name)
        agg_mod::Events.const_get(event_name)
      end

      def resolve_aggregate_module(ctx, agg_name)
        ctx.default? ? @mod.const_get(agg_name) : @mod.const_get(ctx.module_name).const_get(agg_name)
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
