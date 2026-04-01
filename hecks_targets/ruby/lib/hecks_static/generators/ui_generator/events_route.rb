# HecksStatic::UIGenerator::EventsRoute
#
# Generates the /events page route for the static UI server. Lists all
# domain events from the Bluebook IR grouped by aggregate, showing each
# event's name and attributes.
#
#   lines = events_route(mod)
#   # => ["server.mount_proc \"/events\" do ...", ...]
#
module HecksStatic
  class UIGenerator < Hecks::Generator
    module EventsRoute
      include HecksTemplating::NamingHelpers
      private

      def events_route(mod)
        event_rows = @domain.aggregates.flat_map do |agg|
          p = plural(agg)
          agg.events.map do |evt|
            attrs = evt.attributes.map(&:name).join(", ")
            attrs = "(none)" if attrs.empty?
            "{ name: \"#{evt.name}\", aggregate: \"#{agg.name}\", " \
              "aggregate_href: \"/#{p}\", attributes: \"#{attrs}\" }"
          end
        end

        [
          "        server.mount_proc \"/events\" do |req, res|",
          "          next unless req.request_method == \"GET\"",
          "          html = renderer.render(:events, title: \"Events — #{mod}\", brand: brand, nav_items: nav,",
          "            events: [#{event_rows.join(', ')}])",
          "          res[\"Content-Type\"] = \"text/html\"; res.body = html",
          "        end",
          ""
        ]
      end
    end
  end
end
