# Hecks::Generators::Infrastructure::SpecGenerator::EventSpec
#
# Generates RSpec specs for events: frozen state, timestamp,
# and attribute carriage. Mixed into SpecGenerator.
#
module Hecks
  module Generators
    module Infrastructure
      class SpecGenerator
        module EventSpec
          def generate_event_spec(event, aggregate)
            safe_agg = Hecks::Utils.sanitize_constant(aggregate.name)
            fqn = full_class_name("#{safe_agg}::Events::#{event.name}")
            lines = []

            lines << "require \"spec_helper\""
            lines << ""
            lines << "RSpec.describe #{fqn} do"
            lines << "  subject(:event) { described_class.new(#{example_args(event)}) }"
            lines << ""
            lines << "  it \"is frozen\" do"
            lines << "    expect(event).to be_frozen"
            lines << "  end"
            lines << ""
            lines << "  it \"records when it occurred\" do"
            lines << "    expect(event.occurred_at).to be_a(Time)"
            lines << "  end"

            event.attributes.each do |attr|
              lines << ""
              if %w[Date DateTime].include?(attr.type.to_s)
                lines << "  it \"carries #{attr.name}\" do"
                lines << "    expect(event.#{attr.name}).not_to be_nil"
                lines << "  end"
              else
                lines << "  it \"carries #{attr.name}\" do"
                lines << "    expect(event.#{attr.name}).to eq(#{example_value(attr)})"
                lines << "  end"
              end
            end

            lines << "end"
            lines.join("\n") + "\n"
          end
        end
      end
    end
  end
end
