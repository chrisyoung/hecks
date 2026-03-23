# Hecks::Generators::Domain::EventGenerator
#
# Generates frozen domain event classes nested under Aggregate::Events.
# Each event records an occurred_at timestamp and freezes on creation.
# Handles Ruby keyword-safe attribute names via **kwargs. Part of
# Generators::Domain, consumed by DomainGemGenerator and SourceBuilder.
#
#   gen = EventGenerator.new(event, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    module Events\n  ..."
#
module Hecks
  module Generators
    module Domain
    class EventGenerator

      def initialize(event, domain_module:, aggregate_name:)
        @event = event
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @has_keyword_attrs = @event.attributes.any? { |a| Hecks::Utils.ruby_keyword?(a.name) }
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    module Events"
        lines << "      class #{@event.name}"
        lines << "        attr_reader #{@event.attributes.map { |a| ":#{a.name}" }.join(", ")}, :occurred_at"
        lines << ""
        if @has_keyword_attrs
          lines << "        def initialize(**kwargs)"
          @event.attributes.each do |attr|
            lines << "          @#{attr.name} = kwargs[:#{attr.name}]"
          end
        else
          lines << "        def initialize(#{constructor_params})"
          @event.attributes.each do |attr|
            lines << "          @#{attr.name} = #{attr.name}"
          end
        end
        lines << "          @occurred_at = Time.now"
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
        @event.attributes.map { |attr| "#{attr.name}: nil" }.join(", ")
      end
    end
    end
  end
end
