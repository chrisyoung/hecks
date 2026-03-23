# Hecks::EventStorm::Parser::ContextGrouping
#
# Mixin that splits event storm text into bounded contexts and groups
# parsed elements by context markers (## Bounded Context: Name).
#
# Architecture: included by Hecks::EventStorm::Parser. Relies on the host
# class defining PATTERNS, ParsedContext, and the PatternMatching mixin
# (for parse_line and normalize_name).
#
#   contexts = extract_contexts(lines)
#   contexts.first.name  # => "Ordering"
#
module Hecks
  module EventStorm
    class Parser
      module ContextGrouping
        private

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

        def wire_policies_to_commands(elements)
          elements.each_with_index do |el, i|
            next unless el.type == :policy
            next_cmd = elements[(i + 1)..].find { |e| e.type == :command }
            el.meta[:trigger] = next_cmd.name if next_cmd
          end
        end
      end
    end
  end
end
