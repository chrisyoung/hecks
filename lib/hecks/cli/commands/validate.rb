# Hecks::CLI validate command
#
module Hecks
  class CLI < Thor
    desc "validate", "Validate the domain definition"
    def validate
      domain_file = find_domain_file
      unless domain_file
        say "No domain.rb found in current directory", :red
        return
      end
      domain = load_domain(domain_file)
      validator = Validator.new(domain)
      if validator.valid?
        say "Domain is valid", :green
        say ""
        say "Aggregates:"
        domain.aggregates.each do |agg|
          say "  #{agg.name}"
          say "    Attributes:     #{agg.attributes.map(&:name).join(', ')}"
          say "    Value Objects:  #{agg.value_objects.map(&:name).join(', ')}" unless agg.value_objects.empty?
          say "    Commands:       #{agg.commands.map(&:name).join(', ')}" unless agg.commands.empty?
          say "    Events:         #{agg.events.map(&:name).join(', ')}" unless agg.events.empty?
          say "    Policies:       #{agg.policies.map(&:name).join(', ')}" unless agg.policies.empty?
        end
      else
        say "Domain validation failed:", :red
        validator.errors.each { |e| say "  - #{e}", :red }
      end
    end
  end
end
