# Hecks::Generators::Domain::AggregateGenerator
#
# Generates the aggregate root class with identity, validation, and invariants.
#
#   gen = AggregateGenerator.new(agg, domain_module: "PizzasDomain")
#   gen.generate  # => "module PizzasDomain\n  class Pizza\n  ..."
#
module Hecks
  module Generators
    module Domain
    class AggregateGenerator

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
        if @has_keyword_attrs
          lines << "    def initialize(**kwargs)"
          lines << "      @id = kwargs[:id] || generate_id"
          @user_attrs.each do |attr|
            if attr.list?
              lines << "      @#{attr.name} = (kwargs[:#{attr.name}] || []).freeze"
            elsif attr.default
              lines << "      @#{attr.name} = kwargs.fetch(:#{attr.name}, #{attr.default.inspect})"
            else
              lines << "      @#{attr.name} = kwargs[:#{attr.name}]"
            end
          end
          lines << "      @created_at = kwargs[:created_at] || Time.now"
          lines << "      @updated_at = kwargs[:updated_at] || Time.now"
        else
          lines << "    def initialize(#{constructor_params})"
          lines << "      @id = id || generate_id"
          @user_attrs.each do |attr|
            if attr.list?
              lines << "      @#{attr.name} = #{attr.name}.freeze"
            else
              lines << "      @#{attr.name} = #{attr.name}"
            end
          end
          lines << "      @created_at = created_at || Time.now"
          lines << "      @updated_at = updated_at || Time.now"
        end
        lines << "      validate!"
        lines << "      check_invariants!"
        lines << "    end"
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

      def constructor_params
        params = @user_attrs.map do |attr|
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
          return ["    def validate!; end"]
        end

        lines = ["    def validate!"]
        @aggregate.validations.each do |v|
          field = v.field
          rules = v.rules

          if rules[:presence]
            lines << "      raise ValidationError, \"#{field} can't be blank\" if #{field}.nil? || (#{field}.respond_to?(:empty?) && #{field}.empty?)"
          end

          if rules[:type]
            lines << "      raise ValidationError, \"#{field} must be a #{rules[:type]}\" unless #{field}.is_a?(#{rules[:type]})"
          end
        end
        lines << "    end"
        lines
      end

      def invariant_lines
        if @aggregate.invariants.empty?
          return ["    def check_invariants!; end"]
        end

        lines = []
        lines << "    INVARIANTS = {"
        @aggregate.invariants.each do |inv|
          lines << "      #{inv.message.inspect} => #{source_from_block(inv.block)},"
        end
        lines << "    }.freeze"
        lines << ""
        lines << "    def check_invariants!"
        @aggregate.invariants.each do |inv|
          lines << "      raise InvariantError, #{inv.message.inspect} unless instance_eval(&INVARIANTS[#{inv.message.inspect}])"
        end
        lines << "    end"
        lines
      end

      def source_from_block(block)
        "proc { #{Hecks::Utils.block_source(block)} }"
      end
    end
    end
  end
end
