# Hecks::Generators::Infrastructure::SpecGenerator::ValueObjectSpec
#
# Generates RSpec specs for value objects: immutability, equality,
# and invariant enforcement. Mixed into SpecGenerator.
#
module Hecks
  module Generators
    module Infrastructure
      class SpecGenerator
        module ValueObjectSpec
          def generate_value_object_spec(value_object, aggregate)
            safe_agg = Hecks::Utils.sanitize_constant(aggregate.name)
            fqn = full_class_name("#{safe_agg}::#{value_object.name}")
            snake = Hecks::Utils.underscore(value_object.name)
            lines = []

            lines << "require \"spec_helper\""
            lines << ""
            lines << "RSpec.describe #{fqn} do"
            lines << "  subject(:#{snake}) { described_class.new(#{example_args(value_object)}) }"
            lines << ""
            lines << "  it \"is immutable\" do"
            lines << "    expect(#{snake}).to be_frozen"
            lines << "  end"
            lines << ""
            lines << "  it \"is equal when all attributes match\" do"
            lines << "    other = described_class.new(#{example_args(value_object)})"
            lines << "    expect(#{snake}).to eq(other)"
            lines << "  end"

            value_object.invariants.each do |inv|
              lines << ""
              lines << "  it \"enforces: #{inv.message}\" do"
              lines << "    # TODO: construct a #{value_object.name} that violates: #{inv.message}"
              lines << "    # expect { described_class.new(...) }.to raise_error(#{mod_name}::InvariantError)"
              lines << "  end"
            end

            lines << "end"
            lines.join("\n") + "\n"
          end
        end
      end
    end
  end
end
