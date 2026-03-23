# Hecks::Services::Application
#
# The application container that wires a domain to adapters, dispatches
# commands, publishes events, and executes policies. Defaults to memory
# adapters for all aggregates.
#
# Single context:
#   app = Application.new(domain)
#   app["Pizza"].all
#   Pizza.create_pizza(name: "Margherita")
#
# Multiple contexts:
#   app = Application.new(domain)
#   app["Ordering"]["Order"].all
#   Ordering::Order.place_order(quantity: 3)
#
# Custom adapters:
#   app = Application.new(domain) do
#     adapter "Pizza", my_sql_repo  # single context
#     adapter "Ordering", "Order", my_sql_repo  # multi context
#   end
#
require_relative "aggregate_wiring"

module Hecks
  module Services
    class Application
      attr_reader :domain, :event_bus, :command_bus

      def initialize(domain, port: nil, &config)
        @domain = domain
        @port_name = port
        @mod_name = domain.module_name + "Domain"
        @mod = Object.const_get(@mod_name)
        @event_bus = EventBus.new
        @repositories = {}
        @adapter_overrides = {}

        instance_eval(&config) if config

        setup_repositories
        setup_command_bus
        setup_policies
        AggregateWiring.new(@domain, @repositories, @command_bus, @mod, port_name: @port_name).wire!
        hoist_constants
      end

      # Register command bus middleware
      #
      #   app.use :logging do |command, next_handler|
      #     puts command.class.name
      #     next_handler.call
      #   end
      #
      def use(name = nil, &block)
        @command_bus.use(name, &block)
      end

      # Configuration DSL: override adapter for an aggregate
      # Single context:  adapter "Pizza", repo_instance
      # Multi context:   adapter "Ordering", "Order", repo_instance
      def adapter(*args)
        case args.size
        when 2
          aggregate_name, adapter_obj = args
          @adapter_overrides[aggregate_name.to_s] = adapter_obj
        when 3
          context_name, aggregate_name, adapter_obj = args
          @adapter_overrides["#{context_name}/#{aggregate_name}"] = adapter_obj
        end
      end

      # Get the repository for an aggregate
      # Single context: app["Pizza"]
      # Multi context:  app["Ordering"] returns a ContextProxy, then app["Ordering"]["Order"]
      def [](name)
        if @domain.single_context?
          @repositories[name.to_s]
        else
          ctx = @domain.find_context(name.to_s)
          if ctx
            ContextProxy.new(ctx, @repositories)
          else
            @repositories[name.to_s]
          end
        end
      end

      # Execute a command through the command bus (with middleware)
      def run(command_name, **attrs)
        @command_bus.dispatch(command_name, **attrs)
      end

      # Subscribe to an event
      def on(event_name, &handler)
        @event_bus.subscribe(event_name, &handler)
      end

      # All published events
      def events
        @event_bus.events
      end

      def inspect
        "#<Hecks::Services::Application \"#{@domain.name}\" (#{@repositories.size} repositories)>"
      end

      private

      def setup_repositories
        @domain.contexts.each do |ctx|
          ctx.aggregates.each do |agg|
            key = ctx.default? ? agg.name : "#{ctx.name}/#{agg.name}"
            override_key = ctx.default? ? agg.name : "#{ctx.name}/#{agg.name}"

            if @adapter_overrides.key?(override_key)
              @repositories[key] = @adapter_overrides[override_key]
            elsif @adapter_overrides.key?(agg.name) && ctx.default?
              @repositories[key] = @adapter_overrides[agg.name]
            else
              adapter_class = resolve_memory_adapter(ctx, agg)
              @repositories[key] = adapter_class.new
            end
          end
        end
      end

      def resolve_memory_adapter(ctx, agg)
        if ctx.default?
          @mod::Adapters.const_get("#{agg.name}MemoryRepository")
        else
          @mod::Adapters.const_get(ctx.module_name).const_get("#{agg.name}MemoryRepository")
        end
      end

      def setup_policies
        @domain.aggregates.each do |agg|
          agg.policies.each do |policy|
            @event_bus.subscribe(policy.event_name) do |event|
              event_attrs = {}
              event.class.instance_method(:initialize).parameters.each do |_, name|
                next unless name
                event_attrs[name] = event.send(name) if event.respond_to?(name)
              end
              @command_bus.dispatch(policy.trigger_command, **event_attrs)
            rescue StandardError => e
              warn "[Hecks] Policy #{policy.name} failed: #{e.message}"
            end
          end
        end
      end

      def setup_command_bus
        @command_bus = Commands::CommandBus.new(
          domain: @domain,
          event_bus: @event_bus
        )
      end

      def hoist_constants
        if @domain.single_context?
          @domain.aggregates.each do |agg|
            klass = resolve_aggregate_class(@domain.contexts.first, agg)
            silence_warnings { Object.const_set(agg.name, klass) }
          end
        else
          @domain.contexts.each do |ctx|
            next if ctx.default?
            ctx_mod = @mod.const_get(ctx.module_name)
            silence_warnings { Object.const_set(ctx.module_name, ctx_mod) }
          end
        end
      end

      def silence_warnings
        old = $VERBOSE
        $VERBOSE = nil
        yield
      ensure
        $VERBOSE = old
      end

      def resolve_aggregate_class(ctx, agg)
        if ctx.default?
          @mod.const_get(agg.name)
        else
          @mod.const_get(ctx.module_name).const_get(agg.name)
        end
      end

    end
  end
end
