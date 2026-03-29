
module Hecks
  module Commands
    # Hecks::Commands::CommandRunner
    #
    # LEGACY -- replaced by CommandBus, which adds middleware support.
    # Kept for backward compatibility. New code should use CommandBus instead.
    #
    # Dispatches commands through the domain. Resolves command and event classes
    # from the domain module namespace, creates events by mapping command attributes
    # to event constructor parameters, and publishes them on the event bus.
    #
    # == Usage
    #
    #   runner = CommandRunner.new(domain: domain, repositories: repos, event_bus: bus)
    #   runner.run("CreatePizza", name: "Margherita")
    #   # => #<PizzasDomain::Pizza::Events::CreatedPizza>
    #
    class CommandRunner
      include Hecks::NamingHelpers
      # Initializes the runner with a domain definition, repositories, and event bus.
      #
      # @param domain [Hecks::DomainModel::Structure::Domain] the domain IR containing
      #   aggregate, command, and event metadata
      # @param repositories [Hash] a hash of aggregate name to repository instance
      #   (not used directly in dispatch, but available for future extension)
      # @param event_bus [Hecks::EventBus] the event bus for publishing domain events
      def initialize(domain:, repositories:, event_bus:)
        @domain = domain
        @repositories = repositories
        @event_bus = event_bus
        @mod = Object.const_get(domain_module_name(domain.name))
      end

      # Dispatches a command by name, creates the corresponding event, and publishes it.
      #
      # Resolves the command and event definitions from the domain IR, instantiates
      # the command with the given attributes, builds a matching event by extracting
      # overlapping attributes, and publishes the event on the event bus.
      #
      # @param command_name [String, Symbol] the command name (e.g., "CreatePizza")
      # @param attrs [Hash] keyword arguments passed to the command constructor
      # @return [Object] the domain event that was created and published
      # @raise [RuntimeError] if the command name cannot be found in any aggregate
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

      # Resolves a command name to its aggregate, command, and event definitions.
      #
      # Iterates through all aggregates and their commands to find a match.
      # Commands and events are paired by index (command[i] corresponds to event[i]).
      #
      # @param command_name [String, Symbol] the command name to look up
      # @return [Array<(Aggregate, Command, Event)>] the matching aggregate, command,
      #   and event definitions
      # @raise [RuntimeError] if no matching command is found, listing all available commands
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

      # Resolves the Ruby command class from the domain module namespace.
      #
      # @param agg_name [String] the aggregate name (e.g., "Pizza")
      # @param command_name [String, Symbol] the command name (e.g., "CreatePizza")
      # @return [Class] the command class (e.g., +PizzasDomain::Pizza::Commands::CreatePizza+)
      def resolve_command_class(agg_name, command_name)
        agg_mod = @mod.const_get(agg_name)
        agg_mod::Commands.const_get(command_name)
      end

      # Resolves the Ruby event class from the domain module namespace.
      #
      # @param agg_name [String] the aggregate name (e.g., "Pizza")
      # @param event_name [String] the event name (e.g., "CreatedPizza")
      # @return [Class] the event class (e.g., +PizzasDomain::Pizza::Events::CreatedPizza+)
      def resolve_event_class(agg_name, event_name)
        agg_mod = @mod.const_get(agg_name)
        agg_mod::Events.const_get(event_name)
      end

      # Extracts attributes from a command that match the event's constructor parameters.
      #
      # Inspects the event class's +initialize+ method to determine which parameters
      # it accepts, then copies matching values from the command object.
      #
      # @param command [Object] the command instance to extract attributes from
      # @param event_class [Class] the event class whose constructor defines the target attributes
      # @return [Hash<Symbol, Object>] keyword arguments for constructing the event
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
