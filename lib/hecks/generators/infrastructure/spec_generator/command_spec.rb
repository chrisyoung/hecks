# Hecks::Generators::Infrastructure::SpecGenerator::CommandSpec
#
# Generates RSpec specs for commands: attribute assignment and
# event emission declarations. Mixed into SpecGenerator.
#
module Hecks
  module Generators
    module Infrastructure
      class SpecGenerator
        module CommandSpec
          def generate_command_spec(command, aggregate)
            safe_agg = Hecks::Utils.sanitize_constant(aggregate.name)
            fqn = full_class_name("#{safe_agg}::Commands::#{command.name}")
            event_name = command.inferred_event_name
            lines = []

            lines << "require \"spec_helper\""
            lines << ""
            lines << "RSpec.describe #{fqn} do"
            lines << "  describe \"attributes\" do"
            lines << "    subject(:command) { described_class.new(#{example_args(command)}) }"
            lines << ""
            command.attributes.each do |attr|
              lines << "    it \"has #{attr.name}\" do"
              lines << "      expect(command.#{attr.name}).to eq(#{example_value(attr)})"
              lines << "    end"
              lines << ""
            end
            lines << "  end"
            lines << ""
            lines << "  describe \"event\" do"
            lines << "    it \"emits #{event_name}\" do"
            lines << "      expect(described_class.event_name).to eq(\"#{event_name}\")"
            lines << "    end"
            lines << "  end"
            lines << "end"
            lines.join("\n") + "\n"
          end
        end
      end
    end
  end
end
