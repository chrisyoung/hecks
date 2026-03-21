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
#   parser = Parser.new(File.read("storm.md"))
#   result = parser.parse
#   result.contexts.first.name  # => "Ordering"
#
module Hecks
  module EventStorm
    class Parser
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

      private

      def extract_domain_name(lines)
        lines.each do |line|
          next if line.strip.empty? || line.start_with?("##")
          match = line.match(PATTERNS[:domain])
          return match[1].strip if match && !line.include?("LEGEND") && !line.include?("=====")
        end
        nil
      end

      def extract_contexts(lines)
        chunks = split_by_context(lines)
        contexts = chunks.map { |name, ctx_lines| parse_context(name, ctx_lines) }
        contexts.reject { |ctx| ctx.elements.empty? }
      end

      def split_by_context(lines)
        contexts = []
        current_name = "Default"
        current_lines = []

        lines.each do |line|
          match = line.match(PATTERNS[:context])
          if match
            contexts << [current_name, current_lines] unless current_lines.empty?
            current_name = match[1].strip
            current_lines = []
          else
            current_lines << line
          end
        end

        contexts << [current_name, current_lines] unless current_lines.empty?
        contexts
      end

      def parse_context(name, lines)
        elements = []
        current_command = nil

        lines.each do |line|
          cleaned = line.gsub(/^[\s|v+\->]+/, "")
          next if cleaned.empty? || cleaned.start_with?("#") || cleaned.include?("LEGEND") ||
                  cleaned.include?("=====")

          parsed = parse_line(cleaned)
          next unless parsed

          if parsed[:command]
            current_command = parsed[:command]
            elements << current_command
          end

          if parsed[:event]
            elements << parsed[:event]
            current_command = nil
          end

          if parsed[:policy]
            elements << parsed[:policy]
            current_command = nil
          end

          if parsed[:aggregate] && current_command
            current_command.meta[:aggregate] = parsed[:aggregate].name
          end

          if parsed[:read_model] && current_command
            current_command.meta[:read_models] ||= []
            current_command.meta[:read_models] << parsed[:read_model].name
          end

          if parsed[:external] && current_command
            current_command.meta[:external_systems] ||= []
            current_command.meta[:external_systems] << parsed[:external].name
          elsif parsed[:external]
            elements << parsed[:external]
          end

          elements << parsed[:actor] if parsed[:actor]
          elements << parsed[:hotspot] if parsed[:hotspot]
        end

        wire_policies_to_commands(elements)
        ParsedContext.new(name: name, elements: elements)
      end

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

      def wire_policies_to_commands(elements)
        elements.each_with_index do |el, i|
          next unless el.type == :policy
          next_cmd = elements[(i + 1)..].find { |e| e.type == :command }
          el.meta[:trigger] = next_cmd.name if next_cmd
        end
      end

      def normalize_name(name)
        name.split(/\s+/).map(&:capitalize).join
      end
    end
  end
end
