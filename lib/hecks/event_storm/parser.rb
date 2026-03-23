# Hecks::EventStorm::Parser
#
# Parses an ASCII event storm document into a structured intermediate
# representation. Recognizes bounded contexts, commands, events, aggregates,
# policies, actors, read models, external systems, and hotspots.
#
# The notation uses bracket shapes to encode concept types:
#   >>Event<<  [Command]  (Aggregate)  {When X, Y}  <ReadModel>
#   [[External]]  Actor: Name  !!Hotspot!!
#
# Pattern matching logic lives in Parser::PatternMatching; context splitting
# and element grouping live in Parser::ContextGrouping.
#
#   parser = Parser.new(File.read("storm.md"))
#   result = parser.parse
#   result.contexts.first.name  # => "Ordering"
#
require_relative "parser/pattern_matching"
require_relative "parser/context_grouping"

module Hecks
  module EventStorm
    class Parser
      include PatternMatching
      include ContextGrouping

      PATTERNS = {
        domain:    /^#\s+(.+?)(?:\s*[-—=]+.*)?$/,
        context:   /^##\s+Bounded Context:\s*(.+)$/,
        event:     />>(.+?)<</,
        command:   /\[([^\[\]]+)\]/,
        aggregate: /\(([^()]+)\)/,
        policy:    /\{When\s+(.+?),\s*(.+?)\}/,
        read_model: /<([^<>]+)>/,
        external:  /\[\[(.+?)\]\]/,
        actor:     /^[\s|v+\->]*Actor:\s*(.+)$/,
        hotspot:   /!!(.+?)!!/,
      }.freeze

      ParseResult = Struct.new(:domain_name, :contexts, :warnings, keyword_init: true)
      ParsedContext = Struct.new(:name, :elements, keyword_init: true)
      ParsedElement = Struct.new(:type, :name, :meta, keyword_init: true)

      def initialize(source)
        @source = source
        @warnings = []
      end

      def parse
        lines = @source.lines.map(&:rstrip)
        domain_name = extract_domain_name(lines)
        contexts = extract_contexts(lines)

        ParseResult.new(domain_name: domain_name, contexts: contexts, warnings: @warnings)
      end
    end
  end
end
