# Hecks::DomainInspector
#
# Top-level introspection across all loaded domains. Provides Hecks.commands,
# Hecks.queries, Hecks.policies, Hecks.aggregates, and Hecks.glossary.
#
#   Hecks.commands   # => ["Pizza.CreatePizza(name: String) -> CreatedPizza"]
#   Hecks.glossary   # prints full glossary to stdout
#
module Hecks
  module DomainInspector
    def commands
      each_aggregate.flat_map do |agg|
        agg.commands.each_with_index.map do |cmd, i|
          event = agg.events[i]
          attrs = cmd.attributes.map { |a| "#{a.name}: #{Utils.type_label(a)}" }.join(", ")
          "#{agg.name}.#{cmd.name}(#{attrs}) -> #{event&.name}"
        end
      end
    end

    def queries
      each_aggregate.flat_map do |agg|
        agg.queries.map { |q| "#{agg.name}.#{q.name}" }
      end
    end

    def policies
      result = each_aggregate.flat_map do |agg|
        agg.policies.map do |pol|
          async = pol.async ? " [async]" : ""
          "#{agg.name}: #{pol.event_name} -> #{pol.trigger_command}#{async}"
        end
      end

      @domain_objects.each_value do |domain|
        domain.policies.each do |pol|
          async = pol.async ? " [async]" : ""
          result << "#{domain.name}: #{pol.event_name} -> #{pol.trigger_command}#{async}"
        end
      end

      result
    end

    def aggregates
      each_aggregate.map do |agg|
        attrs = agg.attributes.map { |a| "#{a.name}: #{Utils.type_label(a)}" }.join(", ")
        "#{agg.name} (#{attrs})"
      end
    end

    def glossary
      @domain_objects.each_value { |domain| DomainGlossary.new(domain).print }
      nil
    end

    private

    def each_aggregate
      @domain_objects.flat_map { |_, domain| domain.aggregates }
    end
  end
end
