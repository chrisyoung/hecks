# Hecks::Generators::Domain::ValueObjectGenerator
#
# Generates frozen, immutable value object classes with value-based
# equality (==, eql?, hash). Supports invariant checks, list attributes
# that freeze on creation, and Ruby keyword-safe attribute names via
# **kwargs. Part of Generators::Domain, consumed by DomainGemGenerator
# and InMemoryLoader.
#
#   gen = ValueObjectGenerator.new(vo, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    class Topping\n  ..."
#
module Hecks
  module Generators
    module Domain
    class ValueObjectGenerator

      def initialize(value_object, domain_module:, aggregate_name:)
        @vo = value_object
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @has_keyword_attrs = @vo.attributes.any? { |a| Hecks::Utils.ruby_keyword?(a.name) }
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  class #{@aggregate_name}"
        lines << "    class #{@vo.name}"
        lines << "      attr_reader #{@vo.attributes.map { |a| ":#{a.name}" }.join(", ")}"
        lines << ""
        if @has_keyword_attrs
          lines << "      def initialize(**kwargs)"
          @vo.attributes.each do |attr|
            if attr.list?
              lines << "        @#{attr.name} = (kwargs[:#{attr.name}] || []).freeze"
            else
              lines << "        @#{attr.name} = kwargs[:#{attr.name}]"
            end
          end
        else
          lines << "      def initialize(#{constructor_params})"
          @vo.attributes.each do |attr|
            if attr.list?
              lines << "        @#{attr.name} = #{attr.name}.freeze"
            else
              lines << "        @#{attr.name} = #{attr.name}"
            end
          end
        end
        lines << "        check_invariants!"
        lines << "        freeze"
        lines << "      end"
        lines << ""
        lines << "      def ==(other)"
        if @has_keyword_attrs
          lines << "        other.is_a?(Object.instance_method(:class).bind_call(self)) &&"
          @vo.attributes.each_with_index do |attr, i|
            suffix = i < @vo.attributes.size - 1 ? " &&" : ""
            lines << "          send(:#{attr.name}) == other.send(:#{attr.name})#{suffix}"
          end
        else
          lines << "        other.is_a?(self.class) &&"
          @vo.attributes.each_with_index do |attr, i|
            suffix = i < @vo.attributes.size - 1 ? " &&" : ""
            lines << "          #{attr.name} == other.#{attr.name}#{suffix}"
          end
        end
        lines << "      end"
        lines << "      alias eql? =="
        lines << ""
        lines << "      def hash"
        if @has_keyword_attrs
          lines << "        [Object.instance_method(:class).bind_call(self), #{@vo.attributes.map { |a| "send(:#{a.name})" }.join(", ")}].hash"
        else
          lines << "        [self.class, #{@vo.attributes.map(&:name).join(", ")}].hash"
        end
        lines << "      end"
        lines << ""
        lines << "      private"
        lines << ""
        lines.concat(invariant_lines)
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def constructor_params
        @vo.attributes.map do |attr|
          attr.list? ? "#{attr.name}: []" : "#{attr.name}:"
        end.join(", ")
      end

      def invariant_lines
        if @vo.invariants.empty?
          return ["      def check_invariants!; end"]
        end

        lines = []
        lines << "      def check_invariants!"
        @vo.invariants.each do |inv|
          lines << "        raise InvariantError, #{inv.message.inspect} unless instance_eval(&#{source_from_block(inv.block)})"
        end
        lines << "      end"
        lines
      end

      def source_from_block(block)
        "proc { #{Hecks::Utils.block_source(block)} }"
      end
    end
    end
  end
end
