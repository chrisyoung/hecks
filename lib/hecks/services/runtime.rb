# Hecks::Runtime
#
# The runtime container that wires a domain to adapters, dispatches
# commands, publishes events, and executes policies. Defaults to memory
# adapters for all aggregates. Created via Hecks.load(domain).
#
#   app = Hecks.load(domain)
#   app["Pizza"].all
#   Pizza.create(name: "Margherita")
#
# Custom adapters:
#   app = Hecks.load(domain) do
#     adapter "Pizza", my_sql_repo
#   end
#
require_relative "aggregate_wiring"
require_relative "runtime/repository_setup"
require_relative "runtime/policy_setup"
require_relative "runtime/subscriber_setup"
require_relative "runtime/constant_hoisting"
require_relative "runtime/connection_setup"

module Hecks
  class Runtime
      include RepositorySetup
      include PolicySetup
      include SubscriberSetup
      include ConstantHoisting
      include ConnectionSetup

      attr_reader :domain, :event_bus, :command_bus

      def initialize(domain, port: nil, event_bus: nil, &config)
        @domain = domain
        @port_name = port
        @mod_name = domain.module_name + "Domain"
        @mod = Object.const_get(@mod_name)
        @mod.extend(Hecks::DomainConnections) unless @mod.respond_to?(:persist_to)
        @event_bus = event_bus || EventBus.new
        @repositories = {}
        @adapter_overrides = {}
        @async_handler = nil

        instance_eval(&config) if config

        setup_repositories
        setup_command_bus
        setup_policies
        setup_subscribers
        setup_connections
        AggregateWiring.new(@domain, @repositories, @command_bus, @mod, port_name: @port_name).wire!
        hoist_constants
      end

      # Register command bus middleware
      def use(name = nil, &block)
        @command_bus.use(name, &block)
      end

      # Configuration DSL: override adapter for an aggregate
      def adapter(aggregate_name, adapter_obj)
        @adapter_overrides[aggregate_name.to_s] = adapter_obj
      end

      # Get the repository for an aggregate
      def [](name)
        @repositories[name.to_s]
      end

      # Execute a command through the command bus (with middleware)
      def run(command_name, **attrs)
        @command_bus.dispatch(command_name, **attrs)
      end

      # Register an async handler for policies marked async: true
      def async(&handler)
        @async_handler = handler
      end

      # Subscribe to an event
      def on(event_name, &handler)
        @event_bus.subscribe(event_name, &handler)
      end

      # All published events
      def events
        @event_bus.events
      end

      # Replace a repository adapter (used by connection gems to swap
      # memory adapters for SQL). Re-wires the aggregate after swapping.
      def swap_adapter(aggregate_name, repo)
        name = aggregate_name.to_s
        @repositories[name] = repo
        AggregateWiring.new(@domain, @repositories, @command_bus, @mod, port_name: @port_name).wire_aggregate!(name)
      end

      def inspect
        "#<Hecks::Runtime \"#{@domain.name}\" (#{@repositories.size} repositories)>"
      end

      private

      def setup_command_bus
        @command_bus = Commands::CommandBus.new(
          domain: @domain,
          event_bus: @event_bus
        )
      end
    end

  # Backward compatibility
  Application = Runtime
end
