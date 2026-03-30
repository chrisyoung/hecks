module Hecks
  class Workshop
    class WebRunner
      # Hecks::Workshop::WebRunner::StateSerializer
      #
      # Serializes the current workshop state into a JSON-ready hash for
      # the browser console. Includes domain tree (aggregates with their
      # attributes, commands, events, etc.) and event log when in play mode.
      #
      #   StateSerializer.new(workshop).serialize
      #   # => { mode: "sketch", domain_name: "Pizzas", aggregates: [...], events: [] }
      #
      class StateSerializer
        def initialize(workshop)
          @workshop = workshop
        end

        def serialize
          aggs = serialize_aggregates
          {
            mode:        @workshop.play? ? "play" : "sketch",
            domain_name: @workshop.name,
            aggregates:  aggs,
            events:      serialize_events,
            mermaid:     build_mermaid(aggs)
          }
        end

        private

        def serialize_aggregates
          @workshop.aggregate_builders.values.map do |builder|
            agg = builder.build
            {
              name:           agg.name,
              attributes:     agg.attributes.map { |a|
                type_str = if a.reference?
                             "reference_to(#{a.type})"
                           elsif a.list?
                             "list_of(#{a.type})"
                           else
                             a.type.to_s
                           end
                { name: a.name, type: type_str }
              },
              commands:       agg.commands.map(&:name),
              events:         agg.events.map(&:name),
              value_objects:  agg.value_objects.map(&:name),
              entities:       agg.entities.map(&:name),
              policies:       agg.policies.map(&:name),
              queries:        agg.queries.map(&:name),
              specifications: agg.specifications.map(&:name)
            }
          end
        end

        def build_mermaid(aggs)
          lines = ["graph LR"]
          agg_names = aggs.map { |a| a[:name] }
          aggs.each do |agg|
            count = agg[:attributes].size
            cmds = agg[:commands].size
            lines << "  #{agg[:name]}[\"#{agg[:name]}<br/><small>#{count} attrs · #{cmds} cmds</small>\"]"
          end
          aggs.each do |agg|
            agg[:attributes].each do |a|
              if a[:type].to_s.include?("reference_to")
                target = a[:type].to_s.gsub(/reference_to\(|\)|"/, "").strip
                label = a[:name].to_s.sub(/_id$/, "")
                lines << "  #{agg[:name]} -->|#{label}| #{target}" if agg_names.include?(target)
              elsif a[:type].to_s.include?("list_of")
                target = a[:type].to_s.gsub(/list_of\(|\)|"/, "").strip
                label = a[:name].to_s.sub(/_id$/, "")
                lines << "  #{agg[:name]} -.->|#{label}| #{target}" if agg_names.include?(target)
              end
            end
          end
          lines.join("\n")
        end

        def serialize_events
          return [] unless @workshop.play? && @workshop.playground
          @workshop.playground.events.map do |e|
            { type: e.class.name.split("::").last, occurred_at: e.occurred_at&.to_s }
          end
        end
      end
    end
  end
end
