# Hecks::Generators::AggregateGenerator
#
# Generates the aggregate root class with identity, validation, and invariants.
# Supports optional context module nesting for bounded contexts.
#
#   gen = AggregateGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n  ..."
#
#   gen = AggregateGenerator.new(agg, domain_module: "PizzasDomain", context_module: "Ordering")
#   gen.generate  # => "module PizzasDomain\n  module Ordering\n    class Order\n  ..."
#
module Hecks
  module Generators
    module Domain
    class AggregateGenerator
      include ContextAware

      def initialize(aggregate, domain_module:, context_module: nil)
        @aggregate = aggregate
        @domain_module = domain_module
        @context_module = context_module
      end

      def generate
        lines = []
        lines.concat(module_open_lines)
        lines << "#{indent}class #{@aggregate.name}"
        lines << "#{indent}  attr_reader :id#{attr_readers}, :created_at, :updated_at"
        lines << ""
        lines << "#{indent}  def initialize(#{constructor_params})"
        lines << "#{indent}    @id = id || generate_id"
        @aggregate.attributes.each do |attr|
          if attr.list?
            lines << "#{indent}    @#{attr.name} = #{attr.name}.freeze"
          else
            lines << "#{indent}    @#{attr.name} = #{attr.name}"
          end
        end
        lines << "#{indent}    @created_at = created_at || Time.now"
        lines << "#{indent}    @updated_at = updated_at || Time.now"
        lines << "#{indent}    validate!"
        lines << "#{indent}    check_invariants!"
        lines << "#{indent}  end"
        lines << ""
        lines << "#{indent}  def ==(other)"
        lines << "#{indent}    other.is_a?(self.class) && id == other.id"
        lines << "#{indent}  end"
        lines << "#{indent}  alias eql? =="
        lines << ""
        lines << "#{indent}  def hash"
        lines << "#{indent}    [self.class, id].hash"
        lines << "#{indent}  end"
        lines << ""
        lines << "#{indent}  private"
        lines << ""
        lines << "#{indent}  def generate_id"
        lines << "#{indent}    SecureRandom.uuid"
        lines << "#{indent}  end"
        lines << ""
        lines.concat(validation_lines)
        lines << ""
        lines.concat(invariant_lines)
        lines << "#{indent}end"
        lines.concat(module_close_lines)
        lines.join("\n") + "\n"
      end

      private

      def attr_readers
        return "" if @aggregate.attributes.empty?
        ", " + @aggregate.attributes.map { |a| ":#{a.name}" }.join(", ")
      end

      def constructor_params
        params = @aggregate.attributes.map do |attr|
          if attr.list?
            "#{attr.name}: []"
          elsif attr.default
            "#{attr.name}: #{attr.default.inspect}"
          else
            "#{attr.name}: nil"
          end
        end
        params << "id: nil"
        params << "created_at: nil"
        params << "updated_at: nil"
        params.join(", ")
      end

      def validation_lines
        if @aggregate.validations.empty?
          return ["#{indent}  def validate!; end"]
        end

        lines = ["#{indent}  def validate!"]
        @aggregate.validations.each do |v|
          field = v.field
          rules = v.rules

          if rules[:presence]
            lines << "#{indent}    raise ValidationError, \"#{field} can't be blank\" if #{field}.nil? || (#{field}.respond_to?(:empty?) && #{field}.empty?)"
          end

          if rules[:type]
            lines << "#{indent}    raise ValidationError, \"#{field} must be a #{rules[:type]}\" unless #{field}.is_a?(#{rules[:type]})"
          end
        end
        lines << "#{indent}  end"
        lines
      end

      def invariant_lines
        if @aggregate.invariants.empty?
          return ["#{indent}  def check_invariants!; end"]
        end

        lines = []
        lines << "#{indent}  INVARIANTS = {"
        @aggregate.invariants.each do |inv|
          lines << "#{indent}    #{inv.message.inspect} => #{source_from_block(inv.block)},"
        end
        lines << "#{indent}  }.freeze"
        lines << ""
        lines << "#{indent}  def check_invariants!"
        @aggregate.invariants.each do |inv|
          lines << "#{indent}    raise InvariantError, #{inv.message.inspect} unless instance_eval(&INVARIANTS[#{inv.message.inspect}])"
        end
        lines << "#{indent}  end"
        lines
      end

      def source_from_block(block)
        "proc { #{Hecks::Utils.block_source(block)} }"
      end
    end
    end
  end
end
