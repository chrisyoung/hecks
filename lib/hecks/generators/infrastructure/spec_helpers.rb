# Hecks::Generators::Infrastructure::SpecHelpers
#
# Private helper methods for SpecGenerator: example argument generation,
# example values by type, and spec snippet builders for attributes,
# validations, invariants, and equality. Part of Generators::Infrastructure,
# mixed into SpecGenerator.
#
#   # Mixed into SpecGenerator:
#   example_args(aggregate)  # => "name: \"example\", size: \"example\""
#
module Hecks
  module Generators
    module Infrastructure
    module SpecHelpers
      private

      def full_class_name(class_path)
        mod = @domain.module_name + "Domain"
        "#{mod}::#{class_path}"
      end

      def example_args(thing)
        parts = thing.attributes.map do |attr|
          "#{attr.name}: #{example_value(attr)}"
        end
        if parts.size <= 2
          parts.join(", ")
        else
          "\n          " + parts.join(",\n          ") + "\n        "
        end
      end

      def example_value(attr)
        return "[]" if attr.list?
        return "\"ref-id-123\"" if attr.reference?
        return attr.enum.first.inspect if attr.enum&.any?

        case attr.type.to_s
        when "String"  then "\"example\""
        when "Integer" then "1"
        when "Float"   then "1.0"
        when "Boolean", "TrueClass", "FalseClass" then "true"
        when "Date"    then "Date.today"
        when "DateTime" then "DateTime.now"
        else "\"example\""
        end
      end

      def attribute_specs(aggregate)
        safe_name = Hecks::Utils.sanitize_constant(aggregate.name)
        snake = Hecks::Utils.underscore(safe_name)
        aggregate.attributes.map do |attr|
          "    it \"has #{attr.name}\" do\n      expect(#{snake}.#{attr.name}).not_to be_nil\n    end"
        end.join("\n\n")
      end

      def validation_specs(aggregate)
        return "" if aggregate.validations.empty?

        specs = aggregate.validations.map do |v|
          field = v.field
          rules = v.rules

          if rules[:presence]
            <<~RUBY.chomp
                describe "validations" do
                  it "requires #{field}" do
                    expect {
                      described_class.new(#{example_args_without(aggregate, field)})
                    }.to raise_error(#{@domain.module_name}Domain::ValidationError)
                  end
                end
            RUBY
          end
        end.compact

        specs.join("\n\n")
      end

      def invariant_specs(vo)
        return "" if vo.invariants.empty?

        "  describe \"invariants\" do\n    it \"enforces invariants\" do\n      # TODO: Add specific invariant test cases\n    end\n  end"
      end

      def equality_spec(aggregate)
        <<~RUBY.chomp
            describe "equality" do
              it "is equal to another #{aggregate.name} with the same id" do
                id = SecureRandom.uuid
                a = described_class.new(#{example_args(aggregate)}, id: id)
                b = described_class.new(#{example_args(aggregate)}, id: id)
                expect(a).to eq(b)
              end
            end
        RUBY
      end

      def example_args_with(thing, **extra)
        parts = thing.attributes.map do |attr|
          "#{attr.name}: #{example_value(attr)}"
        end
        extra.each { |k, v| parts << "#{k}: #{v}" }
        if parts.size <= 2
          parts.join(", ")
        else
          "\n          " + parts.join(",\n          ") + "\n        "
        end
      end

      def example_args_without(thing, excluded_field)
        parts = thing.attributes.map do |attr|
          if attr.name == excluded_field
            "#{attr.name}: nil"
          else
            "#{attr.name}: #{example_value(attr)}"
          end
        end
        if parts.size <= 2
          parts.join(", ")
        else
          "\n          " + parts.join(",\n          ") + "\n        "
        end
      end
    end
    end
  end
end
