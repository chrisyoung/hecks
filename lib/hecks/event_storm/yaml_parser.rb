# Hecks::EventStorm::YamlParser
#
# Parses a YAML event storm document into the same ParseResult structure
# as the ASCII Parser. Accepts a structured YAML format that maps directly
# to event storm concepts: contexts, aggregates, commands, policies, etc.
#
# The YAML format is an alternative to the ASCII notation -- both produce
# identical ParseResult objects consumed by DomainBuilder and DslGenerator.
#
#   parser = YamlParser.new(File.read("storm.yml"))
#   result = parser.parse
#   result.contexts.first.name  # => "Ordering"
#
require "yaml"

module Hecks
  module EventStorm
    class YamlParser
      def initialize(source)
        @data = YAML.safe_load(source, permitted_classes: [Symbol])
        @warnings = []
      end

      def parse
        contexts = parse_contexts
        Parser::ParseResult.new(
          domain_name: @data["domain"],
          contexts: contexts,
          warnings: @warnings
        )
      end

      private

      def parse_contexts
        raw = @data["contexts"] || {}

        if raw.empty? && @data["aggregates"]
          return [parse_context("Default", @data["aggregates"])]
        end

        raw.map { |name, body| parse_context(name, body["aggregates"] || body) }
      end

      def parse_context(name, aggregates_hash)
        elements = []
        aggregates_hash ||= {}

        aggregates_hash.each do |agg_name, agg_body|
          agg_body ||= {}
          parse_aggregate(agg_name, agg_body, elements)
        end

        Parser::ParsedContext.new(name: name, elements: elements)
      end

      def parse_aggregate(agg_name, body, elements)
        commands = body["commands"] || {}
        policies = body["policies"] || {}
        hotspots = body["hotspots"] || []

        hotspots.each do |h|
          elements << make(:hotspot, h)
        end

        commands.each do |cmd_name, cmd_body|
          cmd_body ||= {}
          el = make(:command, normalize(cmd_name), aggregate: normalize(agg_name))

          Array(cmd_body["read_models"]).each do |rm|
            el.meta[:read_models] ||= []
            el.meta[:read_models] << rm
          end

          Array(cmd_body["external_systems"]).each do |ext|
            el.meta[:external_systems] ||= []
            el.meta[:external_systems] << ext
          end

          Array(cmd_body["actors"]).each do |act|
            elements << make(:actor, act)
          end

          if cmd_body["actor"]
            elements << make(:actor, cmd_body["actor"])
          end

          elements << el

          event_name = cmd_body["event"]
          elements << make(:event, normalize(event_name)) if event_name
        end

        policies.each do |policy_name, pol_body|
          pol_body ||= {}
          # YAML 1.1 parses "on" as boolean true, so check both keys
          on_event = normalize(pol_body["on"] || pol_body[true] || "")
          trigger = normalize(pol_body["trigger"] || policy_name)
          elements << make(:policy, normalize(policy_name),
                           event_name: on_event, trigger: trigger)
        end
      end

      def make(type, name, **meta)
        Parser::ParsedElement.new(type: type, name: name, meta: meta)
      end

      def normalize(name)
        name.to_s.split(/\s+/).map(&:capitalize).join
      end
    end
  end
end
