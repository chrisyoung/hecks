# Hecks::Session::SystemBrowser
#
# Smalltalk-inspired system browser. Prints a navigable tree of all
# domain elements — aggregates, attributes, commands, events, policies,
# queries, specifications, and value objects.
#
#   session.browse              # full domain tree
#   session.browse("Account")   # single aggregate
#
module Hecks
  class Session
    module SystemBrowser
      def browse(aggregate_name = nil)
        if aggregate_name
          builder = @aggregate_builders[normalize_name(aggregate_name)]
          return puts("Unknown aggregate: #{aggregate_name}") unless builder
          puts browse_aggregate(builder.build, last: true)
        else
          puts "#{@name} Domain"
          aggs = @aggregate_builders.values.map(&:build)
          aggs.each_with_index do |agg, i|
            puts browse_aggregate(agg, last: i == aggs.size - 1)
          end
        end
        nil
      end

      private

      def browse_aggregate(agg, last: false)
        prefix = last ? "  └── " : "  ├── "
        indent = last ? "      " : "  │   "
        lines = ["#{prefix}#{agg.name}"]
        sections = browse_sections(agg)
        sections.each_with_index do |(label, items), i|
          connector = i == sections.size - 1 ? "└── " : "├── "
          lines << "#{indent}#{connector}#{label}: #{items}"
        end
        lines.join("\n")
      end

      def browse_sections(agg)
        sections = []
        if agg.attributes.any?
          sections << ["attributes", agg.attributes.map { |a| "#{a.name} (#{a.type})" }.join(", ")]
        end
        if agg.value_objects.any?
          sections << ["value objects", agg.value_objects.map(&:name).join(", ")]
        end
        if agg.entities.any?
          sections << ["entities", agg.entities.map(&:name).join(", ")]
        end
        if agg.commands.any?
          sections << ["commands", agg.commands.map(&:name).join(", ")]
        end
        if agg.events.any?
          sections << ["events", agg.events.map(&:name).join(", ")]
        end
        if agg.policies.any?
          sections << ["policies", agg.policies.map(&:name).join(", ")]
        end
        if agg.queries.any?
          sections << ["queries", agg.queries.map(&:name).join(", ")]
        end
        if agg.specifications.any?
          sections << ["specifications", agg.specifications.map(&:name).join(", ")]
        end
        sections
      end
    end
  end
end
