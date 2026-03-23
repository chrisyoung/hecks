# Hecks::Generators::ValueObjectGenerator
#
# Generates immutable value object classes with value-based equality.
# Supports optional context module nesting.
#
#   gen = ValueObjectGenerator.new(vo, domain_module: "PizzasDomain", aggregate_name: "Pizza")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n    class Topping\n  ..."
#
module Hecks
  module Generators
    module Domain
    class ValueObjectGenerator
      include ContextAware

      def initialize(value_object, domain_module:, aggregate_name:, context_module: nil)
        @vo = value_object
        @domain_module = domain_module
        @aggregate_name = aggregate_name
        @context_module = context_module
      end

      def generate
        lines = []
        lines.concat(module_open_lines)
        lines << "#{indent}class #{@aggregate_name}"
        lines << "#{indent}  class #{@vo.name}"
        lines << "#{indent}    attr_reader #{@vo.attributes.map { |a| ":#{a.name}" }.join(", ")}"
        lines << ""
        lines << "#{indent}    def initialize(#{constructor_params})"
        @vo.attributes.each do |attr|
          if attr.list?
            lines << "#{indent}      @#{attr.name} = #{attr.name}.freeze"
          else
            lines << "#{indent}      @#{attr.name} = #{attr.name}"
          end
        end
        lines << "#{indent}      check_invariants!"
        lines << "#{indent}      freeze"
        lines << "#{indent}    end"
        lines << ""
        lines << "#{indent}    def ==(other)"
        lines << "#{indent}      other.is_a?(self.class) &&"
        @vo.attributes.each_with_index do |attr, i|
          suffix = i < @vo.attributes.size - 1 ? " &&" : ""
          lines << "#{indent}        #{attr.name} == other.#{attr.name}#{suffix}"
        end
        lines << "#{indent}    end"
        lines << "#{indent}    alias eql? =="
        lines << ""
        lines << "#{indent}    def hash"
        lines << "#{indent}      [self.class, #{@vo.attributes.map(&:name).join(", ")}].hash"
        lines << "#{indent}    end"
        lines << ""
        lines << "#{indent}    private"
        lines << ""
        lines.concat(invariant_lines)
        lines << "#{indent}  end"
        lines << "#{indent}end"
        lines.concat(module_close_lines)
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
          return ["#{indent}    def check_invariants!; end"]
        end

        lines = []
        lines << "#{indent}    INVARIANTS = {"
        @vo.invariants.each do |inv|
          lines << "#{indent}      #{inv.message.inspect} => #{source_from_block(inv.block)},"
        end
        lines << "#{indent}    }.freeze"
        lines << ""
        lines << "#{indent}    def check_invariants!"
        @vo.invariants.each do |inv|
          lines << "#{indent}      raise InvariantError, #{inv.message.inspect} unless instance_eval(&INVARIANTS[#{inv.message.inspect}])"
        end
        lines << "#{indent}    end"
        lines
      end

      def source_from_block(block)
        "proc { #{Hecks::Utils.block_source(block)} }"
      end
    end
    end
  end
end
