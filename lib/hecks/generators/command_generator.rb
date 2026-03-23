# Hecks::Generators::CommandGenerator
#
# Generates frozen command data objects. Commands describe intent and are
# dispatched through the command bus.
#
#   gen = CommandGenerator.new(cmd, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    module Commands\n  ..."
#
module Hecks
  module Generators
    class CommandGenerator
      include ContextAware

      def initialize(command, domain_module:, aggregate_name:, context_module: nil)
        @command = command
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @context_module = context_module
      end

      def generate
        lines = []
        lines.concat(module_open_lines)
        lines << "#{indent}class #{@aggregate_name}"
        lines << "#{indent}  module Commands"
        lines << "#{indent}    class #{@command.name}"
        lines << "#{indent}      attr_reader #{@command.attributes.map { |a| ":#{a.name}" }.join(", ")}"
        lines << ""
        lines << "#{indent}      def initialize(#{constructor_params})"
        @command.attributes.each do |attr|
          lines << "#{indent}        @#{attr.name} = #{attr.name}"
        end
        lines << "#{indent}        freeze"
        lines << "#{indent}      end"
        lines << "#{indent}    end"
        lines << "#{indent}  end"
        lines << "#{indent}end"
        lines.concat(module_close_lines)
        lines.join("\n") + "\n"
      end

      private

      def constructor_params
        @command.attributes.map { |attr| "#{attr.name}: nil" }.join(", ")
      end
    end
  end
end
