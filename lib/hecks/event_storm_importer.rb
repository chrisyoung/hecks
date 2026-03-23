# Hecks::EventStormImporter
#
# Parses event storm documents (ASCII or YAML) and produces a domain + DSL.
#
#   Hecks.from_event_storm("event_storm.yml")
#   Hecks.from_event_storm("event_storm.md", name: "Pizzas")
#
module Hecks
  module EventStormImporter
    def from_event_storm(source, name: nil)
      content = File.exist?(source.to_s) ? File.read(source) : source
      yaml = source.to_s.match?(/\.ya?ml$/i) || content.match?(/\A\s*(?:domain|contexts|aggregates)\s*:/)
      result = (yaml ? EventStorm::YamlParser : EventStorm::Parser).new(content).parse
      domain_name = name || result.domain_name
      EventStorm::Result.new(
        domain: EventStorm::DomainBuilder.new(result, name: domain_name).build,
        dsl: EventStorm::DslGenerator.new(result, name: domain_name).generate,
        warnings: result.warnings
      )
    end
  end
end
