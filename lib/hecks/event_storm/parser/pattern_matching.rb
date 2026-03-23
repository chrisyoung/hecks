# Hecks::EventStorm::Parser::PatternMatching
#
# Mixin that provides pattern matching and line-parsing logic for the event
# storm parser. Identifies actors, commands, events, policies, aggregates,
# read models, external systems, and hotspots from individual text lines.
#
# Architecture: included by Hecks::EventStorm::Parser. Relies on the host
# class defining PATTERNS and ParsedElement.
#
#   parsed = parse_line("Actor: Chef  [PlacePizza] >>PizzaPlaced<<")
#   parsed[:command].name  # => "PlacePizza"
#
module Hecks
  module EventStorm
    class Parser
      module PatternMatching
        private

        def parse_line(line)
          result = {}

          if (m = line.match(PATTERNS[:actor]))
            result[:actor] = ParsedElement.new(type: :actor, name: m[1].strip, meta: {})
          end

          if (m = line.match(PATTERNS[:policy]))
            result[:policy] = ParsedElement.new(
              type: :policy, name: normalize_name(m[2].strip),
              meta: { event_name: normalize_name(m[1].strip), trigger: normalize_name(m[2].strip) }
            )
          elsif (m = line.match(PATTERNS[:external]))
            result[:external] = ParsedElement.new(type: :external, name: m[1].strip, meta: {})
          end

          if !result[:policy] && !result[:external] && (m = line.match(PATTERNS[:command]))
            result[:command] = ParsedElement.new(type: :command, name: normalize_name(m[1].strip), meta: {})
          end

          if (m = line.match(PATTERNS[:event]))
            result[:event] = ParsedElement.new(type: :event, name: normalize_name(m[1].strip), meta: {})
          end

          if !result[:external] && (m = line.match(PATTERNS[:aggregate]))
            result[:aggregate] = ParsedElement.new(type: :aggregate, name: normalize_name(m[1].strip), meta: {})
          end

          if !result[:external] && !result[:aggregate] && (m = line.match(PATTERNS[:read_model]))
            result[:read_model] = ParsedElement.new(type: :read_model, name: m[1].strip, meta: {})
          end

          if (m = line.match(PATTERNS[:hotspot]))
            result[:hotspot] = ParsedElement.new(type: :hotspot, name: m[1].strip, meta: {})
          end

          result.empty? ? nil : result
        end

        def normalize_name(name)
          name.split(/\s+/).map(&:capitalize).join
        end

        def extract_domain_name(lines)
          lines.each do |line|
            next if line.strip.empty? || line.start_with?("##")
            match = line.match(PATTERNS[:domain])
            return match[1].strip if match && !line.include?("LEGEND") && !line.include?("=====")
          end
          nil
        end
      end
    end
  end
end
