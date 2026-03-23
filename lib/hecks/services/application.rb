# Hecks::Services::Application
#
# The application container that wires a domain to adapters, dispatches
# commands, publishes events, and executes policies. Defaults to memory
# adapters for all aggregates.
#
#   app = Application.new(domain)
#   app["Pizza"].all
#   Pizza.create_pizza(name: "Margherita")
#
# Custom adapters:
#   app = Application.new(domain) do
#     adapter "Pizza", my_sql_repo
#   end
#
require "set"
require_relative "aggregate_wiring"

module Hecks
  module Services
    class Application
      attr_reader :domain, :event_bus, :command_bus

      def initialize(domain, port: nil, event_bus: nil, &config)
        @domain = domain
        @port_name = port
        @mod_name = domain.module_name + "Domain"
        @mod = Object.const_get(@mod_name)
        @event_bus = event_bus || EventBus.new
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
      #   adapter "Pizza", repo_instance
      def adapter(aggregate_name, adapter_obj)
        @adapter_overrides[aggregate_name.to_s] = adapter_obj
      end

      # Get the repository for an aggregate
      #   app["Pizza"]
      def [](name)
        @repositories[name.to_s]
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
        @domain.aggregates.each do |agg|
          if @adapter_overrides.key?(agg.name)
            @repositories[agg.name] = @adapter_overrides[agg.name]
          else
            adapter_class = @mod::Adapters.const_get("#{agg.name}MemoryRepository")
            @repositories[agg.name] = adapter_class.new
          end
        end
      end

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
                @command_bus.dispatch(policy.trigger_command, **event_attrs)
              rescue StandardError => e
                warn "[Hecks] Policy #{policy.name} failed: #{e.message}"
              ensure
                @policies_in_flight.delete(policy_key)
              end
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
        @domain.aggregates.each do |agg|
          klass = @mod.const_get(agg.name)
          silence_warnings { Object.const_set(agg.name, klass) }
        end
      end

      def silence_warnings
        old = $VERBOSE
        $VERBOSE = nil
        yield
      ensure
        $VERBOSE = old
      end

    end
  end
end
