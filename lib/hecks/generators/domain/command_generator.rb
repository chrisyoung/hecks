# Hecks::Generators::Domain::CommandGenerator
#
# Generates frozen command data objects. Commands describe intent and are
# dispatched through the command bus.
#
#   gen = CommandGenerator.new(cmd, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    module Commands\n  ..."
#
module Hecks
  module Generators
    module Domain
    class CommandGenerator

      def initialize(command, domain_module:, aggregate_name:)
        @command = command
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @has_keyword_attrs = @command.attributes.any? { |a| Hecks::Utils.ruby_keyword?(a.name) }
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Commands"
        lines << "      class #{@command.name}"
        lines << "        attr_reader #{@command.attributes.map { |a| ":#{a.name}" }.join(", ")}"
        lines << ""
        if @has_keyword_attrs
          lines << "        def initialize(**kwargs)"
          @command.attributes.each do |attr|
            lines << "          @#{attr.name} = kwargs[:#{attr.name}]"
          end
        else
          lines << "        def initialize(#{constructor_params})"
          @command.attributes.each do |attr|
            lines << "          @#{attr.name} = #{attr.name}"
          end
        end
        lines << "          freeze"
        lines << "        end"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def constructor_params
        @command.attributes.map { |attr| "#{attr.name}: nil" }.join(", ")
      end
    end
    end
  end
end
