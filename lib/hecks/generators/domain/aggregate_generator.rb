# Hecks::Generators::Domain::AggregateGenerator
#
# Generates the aggregate root class using Hecks::Model attribute DSL.
# Only generates custom validations and invariants — everything else
# comes from the mixin.
#
#   gen = AggregateGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n  ..."
#
require_relative "aggregate_generator/validation_generation"
require_relative "aggregate_generator/invariant_generation"

module Hecks
  module Generators
    module Domain
    class AggregateGenerator
      include ValidationGeneration
      include InvariantGeneration

      def initialize(aggregate, domain_module:)
        @aggregate = aggregate
        @domain_module = domain_module
        @safe_name = Hecks::Utils.sanitize_constant(@aggregate.name)
        @user_attrs = @aggregate.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
      end

      def generate
        lines = []
        lines << "require 'hecks/model'"
        lines << ""
        lines << "module #{@domain_module}"
        lines << "  class #{@safe_name}"
        lines << "    include Hecks::Model"
        lines << ""
        @user_attrs.each do |attr|
          lines << "    attribute #{attribute_declaration(attr)}"
        end
        unless @aggregate.validations.empty? && @aggregate.invariants.empty?
          lines << ""
          lines << "    private"
          lines << ""
          lines.concat(validation_lines) unless @aggregate.validations.empty?
          lines << "" unless @aggregate.validations.empty? || @aggregate.invariants.empty?
          lines.concat(invariant_lines) unless @aggregate.invariants.empty?
        end
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def attribute_declaration(attr)
        parts = [":#{attr.name}"]
        if attr.list?
          parts << "default: []"
          parts << "freeze: true"
        elsif attr.default
          parts << "default: #{attr.default.inspect}"
        end
        parts.join(", ")
      end
    end
    end
  end
end
