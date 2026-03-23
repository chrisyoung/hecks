# Hecks::Generators::Domain::AggregateGenerator
#
# Generates the aggregate root class with identity, validation, and invariants.
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
        lines << "module #{@domain_module}"
        lines << "  class #{@safe_name}"
        lines << "    attr_reader :id#{attr_readers}, :created_at, :updated_at"
        lines << ""
        lines.concat(constructor_lines)
        lines << ""
        lines << "    def ==(other)"
        lines << "      other.is_a?(self.class) && id == other.id"
        lines << "    end"
        lines << "    alias eql? =="
        lines << ""
        lines << "    def hash"
        lines << "      [self.class, id].hash"
        lines << "    end"
        lines << ""
        lines << "    private"
        lines << ""
        lines << "    def generate_id"
        lines << "      SecureRandom.uuid"
        lines << "    end"
        lines << ""
        lines.concat(validation_lines)
        lines << ""
        lines.concat(invariant_lines)
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
