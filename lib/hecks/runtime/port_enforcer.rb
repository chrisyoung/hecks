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
module Hecks
  class PortEnforcer
      CLASS_METHODS    = %i[find all count delete where first last create].freeze
      INSTANCE_METHODS = %i[save destroy update].freeze

      def initialize(port_name:)
        @port_name = port_name
      end

      def enforce!(agg, agg_class)
        return unless @port_name

        port_def = agg.ports[@port_name]
        return unless port_def

        restrict_class_methods(agg, agg_class, port_def)
        restrict_instance_methods(agg, agg_class, port_def)
      end

      private

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

      def command_method_names(agg)
        agg.commands.map do |cmd|
          agg_snake = Hecks::Utils.underscore(agg.name)
          Hecks::Utils.underscore(cmd.name).sub(/_#{agg_snake}$/, "").to_sym
        end
      end
  end
end
