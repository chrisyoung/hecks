
module Hecks
  # Hecks::PortEnforcer
  #
  # Applies port-based access restrictions to an aggregate class.
  # For each method not allowed by the port definition, redefines it
  # to raise Hecks::PortAccessDenied.
  #
  # Called by AggregateWiring after all methods have been wired.
  # When no port is specified, this class is not used and all methods
  # remain accessible (backward compatible).
  #
  class PortEnforcer
    include Hecks::Templating::Names
      # Standard class-level methods that may be restricted by a port definition.
      # These are the built-in persistence and query methods wired onto aggregate classes.
      CLASS_METHODS    = %i[find all count delete where first last create].freeze

      # Standard instance-level methods that may be restricted by a port definition.
      # These are the built-in mutation methods wired onto aggregate instances.
      INSTANCE_METHODS = %i[save destroy update].freeze

      # Creates a new PortEnforcer for the given port name.
      #
      # @param port_name [Symbol, nil] the name of the port to enforce, or nil
      #   to skip enforcement entirely
      def initialize(port_name:)
        @port_name = port_name
      end

      # Enforces port restrictions on the given aggregate class.
      #
      # Looks up the port definition from the aggregate's ports hash and
      # restricts any class methods or instance methods that the port does
      # not allow. Restricted methods raise +Hecks::PortAccessDenied+ when called.
      #
      # Returns immediately (no-op) if +@port_name+ is nil or if the aggregate
      # has no port definition matching that name.
      #
      # @param agg [Hecks::DomainModel::Aggregate] the aggregate domain model definition
      # @param agg_class [Class] the runtime aggregate class to restrict
      # @return [void]
      def enforce!(agg, agg_class)
        return unless @port_name

        port_def = agg.ports[@port_name]
        return unless port_def

        restrict_class_methods(agg, agg_class, port_def)
        restrict_instance_methods(agg, agg_class, port_def)
      end

      private

      # Redefines disallowed class-level methods (both standard CRUD and
      # command methods) to raise +Hecks::PortAccessDenied+.
      #
      # @param agg [Hecks::DomainModel::Aggregate] the aggregate definition
      # @param agg_class [Class] the aggregate class to restrict
      # @param port_def [Hecks::DomainModel::Port] the port definition with allow rules
      # @return [void]
      def restrict_class_methods(agg, agg_class, port_def)
        port_name = @port_name
        agg_name = agg.name
        methods_to_check = CLASS_METHODS + command_method_names(agg)

        methods_to_check.each do |m|
          next if port_def.allows?(m)
          next unless agg_class.respond_to?(m)
          agg_class.define_singleton_method(m) do |*args, **kwargs|
            raise Hecks::PortAccessDenied,
                  "#{agg_name}.#{m} is not allowed through the :#{port_name} port"
          end
        end
      end

      # Redefines disallowed instance-level methods (save, destroy, update)
      # to raise +Hecks::PortAccessDenied+.
      #
      # @param agg [Hecks::DomainModel::Aggregate] the aggregate definition
      # @param agg_class [Class] the aggregate class to restrict
      # @param port_def [Hecks::DomainModel::Port] the port definition with allow rules
      # @return [void]
      def restrict_instance_methods(agg, agg_class, port_def)
        port_name = @port_name
        agg_name = agg.name

        INSTANCE_METHODS.each do |m|
          next if port_def.allows?(m)
          agg_class.define_method(m) do |*args, **kwargs|
            raise Hecks::PortAccessDenied,
                  "#{agg_name}##{m} is not allowed through the :#{port_name} port"
          end
        end
      end

      # Returns the derived method names for all commands on this aggregate.
      #
      # Each command name is underscored and has the aggregate name suffix
      # stripped (e.g., "CreatePizza" on aggregate "Pizza" becomes :create).
      #
      # @param agg [Hecks::DomainModel::Aggregate] the aggregate definition
      # @return [Array<Symbol>] the command method names
      def command_method_names(agg)
        agg.commands.map do |cmd|
          domain_command_method(cmd.name, agg.name)
        end
      end
  end
end
