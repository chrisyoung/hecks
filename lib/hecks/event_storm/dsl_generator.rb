# Hecks::EventStorm::DslGenerator
#
# Generates a Hecks Ruby DSL file from a Parser::ParseResult. Produces
# editable source code with TODO placeholders for attributes that need
# to be filled in after the event storm.
#
# Part of the EventStorm module. Used by Hecks.from_event_storm to produce
# the DSL string output.
#
#   result = EventStorm::Parser.new(source).parse
#   dsl = EventStorm::DslGenerator.new(result, name: "Ordering").generate
#   puts dsl  # => "Hecks.domain \"Ordering\" do ..."
#
module Hecks
  module EventStorm
    class DslGenerator
      def initialize(parse_result, name: nil)
        @parse_result = parse_result
        @name = name || parse_result.domain_name || "MyDomain"
      end

      def generate
        lines = ["# Auto-generated from event storm"]
        lines << "Hecks.domain \"#{@name}\" do"

        @parse_result.contexts.each_with_index do |ctx, i|
          lines << "" if i > 0
          generate_context(ctx, lines)
        end

        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def generate_context(ctx, lines)
        aggregates = group_by_aggregate(ctx.elements)
        hotspots = ctx.elements.select { |e| e.type == :hotspot }
        use_context = ctx.name != "Default"

        indent = use_context ? "    " : "  "
        agg_indent = use_context ? "  " : ""

        if use_context
          lines << "  context \"#{ctx.name}\" do"
          hotspots.each { |h| lines << "    # HOTSPOT: #{h.name}" }
        else
          hotspots.each { |h| lines << "  # HOTSPOT: #{h.name}" }
        end

        aggregates.each_with_index do |(agg_name, data), i|
          lines << "" if i > 0
          lines << "#{agg_indent}  aggregate \"#{agg_name}\" do"
          lines << "#{indent}# TODO: add attributes"

          data[:commands].each do |cmd|
            lines << ""
            lines << "#{indent}command \"#{cmd.name}\" do"
            lines << "#{indent}  # TODO: add attributes"
            (cmd.meta[:read_models] || []).each do |rm|
              lines << "#{indent}  read_model \"#{rm}\""
            end
            (cmd.meta[:external_systems] || []).each do |ext|
              lines << "#{indent}  external \"#{ext}\""
            end
            lines << "#{indent}end"
          end

          data[:policies].each do |pol|
            lines << ""
            lines << "#{indent}policy \"#{pol.name}\" do"
            lines << "#{indent}  on \"#{pol.meta[:event_name]}\""
            lines << "#{indent}  trigger \"#{pol.meta[:trigger]}\""
            lines << "#{indent}end"
          end

          lines << "#{agg_indent}  end"
        end

        lines << "  end" if use_context

        append_warnings(lines)
      end

      def group_by_aggregate(elements)
        aggregates = {}
        unassigned = []

        elements.each do |el|
          case el.type
          when :command
            agg_name = el.meta[:aggregate]
            if agg_name
              aggregates[agg_name] ||= { commands: [], policies: [] }
              aggregates[agg_name][:commands] << el
            else
              unassigned << el
            end
          when :policy
            trigger = el.meta[:trigger]
            agg_name = find_aggregate_for_trigger(elements, trigger)
            target = agg_name || aggregates.keys.first || "Default"
            aggregates[target] ||= { commands: [], policies: [] }
            aggregates[target][:policies] << el
          end
        end

        unless unassigned.empty?
          first = aggregates.keys.first || "Default"
          aggregates[first] ||= { commands: [], policies: [] }
          aggregates[first][:commands] = unassigned + aggregates[first][:commands]
        end

        aggregates
      end

      def find_aggregate_for_trigger(elements, trigger_name)
        elements.each do |el|
          next unless el.type == :command && el.name == trigger_name
          return el.meta[:aggregate] if el.meta[:aggregate]
        end
        nil
      end

      def append_warnings(lines)
        @parse_result.warnings.each do |w|
          lines << "  # WARNING: #{w}"
        end
      end
    end
  end
end
