# Hecks::Generators::Infrastructure::SpecGenerator::EntitySpec
#
# Generates RSpec specs for sub-entities: identity, mutability,
# and invariant enforcement. Mixed into SpecGenerator.
#
module Hecks
  module Generators
    module Infrastructure
      class SpecGenerator
        module EntitySpec
          def generate_entity_spec(entity, aggregate)
            safe_agg = Hecks::Utils.sanitize_constant(aggregate.name)
            fqn = full_class_name("#{safe_agg}::#{entity.name}")
            snake = Hecks::Utils.underscore(entity.name)
            lines = []

            lines << "require \"spec_helper\""
            lines << ""
            lines << "RSpec.describe #{fqn} do"
            lines << "  subject(:#{snake}) { described_class.new(#{example_args(entity)}) }"
            lines << ""
            lines << "  it \"has a UUID id\" do"
            lines << "    expect(#{snake}.id).to match(/\\A[0-9a-f-]{36}\\z/)"
            lines << "  end"
            lines << ""
            lines << "  it \"is mutable (not frozen)\" do"
            lines << "    expect(#{snake}).not_to be_frozen"
            lines << "  end"
            lines << ""
            lines << "  it \"uses identity-based equality\" do"
            lines << "    id = SecureRandom.uuid"
            lines << "    a = described_class.new(#{example_args(entity)}, id: id)"
            lines << "    b = described_class.new(#{example_args(entity)}, id: id)"
            lines << "    expect(a).to eq(b)"
            lines << "  end"

            entity.invariants.each do |inv|
              lines << ""
              lines << "  it \"enforces: #{inv.message}\" do"
              lines << "    # TODO: construct a #{entity.name} that violates: #{inv.message}"
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
