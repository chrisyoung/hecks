# Hecks::Generators::Infrastructure::DomainGemGenerator::SpecWriter
#
# Mixin that writes RSpec specs for all aggregates, value objects, commands,
# and events in the domain gem. Delegates to SpecGenerator for spec content.
# Part of DomainGemGenerator, invoked during DomainGemGenerator#generate.
#
#   # Mixed into DomainGemGenerator:
#   generate_specs(root, gem_name, mod)
#
module Hecks
  module Generators
    module Infrastructure
      class DomainGemGenerator
        module SpecWriter
          private

          def generate_specs(root, gem_name, mod)
            sg = SpecGenerator.new(@domain)
            write_file(root, "spec/spec_helper.rb", sg.generate_spec_helper)
            write_file(root, ".rspec", "--format documentation\n--color\n--require spec_helper\n")
            @domain.aggregates.each do |agg|
              snake = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(agg.name))
              write_file(root, "spec/#{snake}/#{snake}_spec.rb", sg.generate_aggregate_spec(agg))
              agg.value_objects.each do |vo|
                write_file(root, "spec/#{snake}/#{Hecks::Utils.underscore(vo.name)}_spec.rb", sg.generate_value_object_spec(vo, agg))
              end
              agg.entities.each do |ent|
                write_file(root, "spec/#{snake}/#{Hecks::Utils.underscore(ent.name)}_spec.rb", sg.generate_entity_spec(ent, agg))
              end
              agg.commands.each do |cmd|
                write_file(root, "spec/#{snake}/commands/#{Hecks::Utils.underscore(cmd.name)}_spec.rb", sg.generate_command_spec(cmd, agg))
              end
              agg.events.each do |evt|
                write_file(root, "spec/#{snake}/events/#{Hecks::Utils.underscore(evt.name)}_spec.rb", sg.generate_event_spec(evt, agg))
              end
            end
          end
        end
      end
    end
  end
end
