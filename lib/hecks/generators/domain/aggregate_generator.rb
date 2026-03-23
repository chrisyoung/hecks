# Hecks::Generators::Domain::AggregateGenerator
#
# Generates the aggregate root class. Includes Hecks::Model for identity,
# auto-discovery, and validation stubs. Only generates constructor,
# custom validations, and invariants.
#
#   gen = AggregateGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n  ..."
#
require_relative "aggregate_generator/constructor_generation"
require_relative "aggregate_generator/validation_generation"
require_relative "aggregate_generator/invariant_generation"

module Hecks
  module Generators
    module Domain
    class AggregateGenerator
      include ConstructorGeneration
      include ValidationGeneration
      include InvariantGeneration

      def initialize(aggregate, domain_module:)
        @aggregate = aggregate
        @domain_module = domain_module
        @safe_name = Hecks::Utils.sanitize_constant(@aggregate.name)
        # Filter out attributes that clash with auto-generated fields
        @user_attrs = @aggregate.attributes.reject { |a| Hecks::Utils::RESERVED_AGGREGATE_ATTRS.include?(a.name.to_s) }
        @has_keyword_attrs = @user_attrs.any? { |a| Hecks::Utils.ruby_keyword?(a.name) }
      end

      def generate
        lines = []
        lines << "require 'hecks/model'"
        lines << ""
        lines << "module #{@domain_module}"
        lines << "  class #{@safe_name}"
        lines << "    include Hecks::Model"
        lines << ""
        unless @user_attrs.empty?
          lines << "    attr_reader " + @user_attrs.map { |a| ":#{a.name}" }.join(", ")
        end
        lines << ""
        lines.concat(constructor_lines)
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

      def attr_readers
        return "" if @user_attrs.empty?
        ", " + @user_attrs.map { |a| ":#{a.name}" }.join(", ")
      end
    end
    end
  end
end
