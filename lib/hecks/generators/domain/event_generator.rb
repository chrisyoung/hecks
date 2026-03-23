# Hecks::Generators::EventGenerator
#
# Generates frozen domain event classes with occurred_at timestamps.
# Events are inferred from commands (CreatePizza -> CreatedPizza).
#
#   gen = EventGenerator.new(event, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    module Events\n  ..."
#
module Hecks
  module Generators
    module Domain
    class EventGenerator
      include ContextAware

      def initialize(event, domain_module:, aggregate_name:, context_module: nil)
        @event = event
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @context_module = context_module
      end

      def generate
        lines = []
        lines.concat(module_open_lines)
        lines << "#{indent}class #{@aggregate_name}"
        lines << "#{indent}  module Events"
        lines << "#{indent}    class #{@event.name}"
        lines << "#{indent}      attr_reader #{@event.attributes.map { |a| ":#{a.name}" }.join(", ")}, :occurred_at"
        lines << ""
        lines << "#{indent}      def initialize(#{constructor_params})"
        @event.attributes.each do |attr|
          lines << "#{indent}        @#{attr.name} = #{attr.name}"
        end
        lines << "#{indent}        @occurred_at = Time.now"
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
        @event.attributes.map { |attr| "#{attr.name}: nil" }.join(", ")
      end
    end
    end
  end
end
