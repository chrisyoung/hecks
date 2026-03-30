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
          {
            mode:        @workshop.play? ? "play" : "sketch",
            domain_name: @workshop.name,
            aggregates:  serialize_aggregates,
            events:      serialize_events
          }
        end

        private

        def serialize_aggregates
          @workshop.aggregate_builders.values.map do |builder|
            agg = builder.build
            {
              name:           agg.name,
              attributes:     agg.attributes.map { |a| { name: a.name, type: a.type.to_s } },
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
