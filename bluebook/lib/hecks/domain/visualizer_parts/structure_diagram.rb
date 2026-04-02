module Hecks
  class DomainVisualizer
    # Hecks::DomainVisualizer::StructureDiagram
    #
    # Builds the Mermaid classDiagram portion showing aggregates, attributes,
    # value objects, entities, and inter-aggregate references. Mixed into
    # DomainVisualizer.
    #
    # Aggregates are rendered as classes with their attributes. Value objects
    # and entities are rendered as separate classes composed into (*--) their
    # parent aggregate. Entities additionally show a +id : UUID attribute.
    # Cross-aggregate references are drawn as directed associations (-->).
    #
    #   include StructureDiagram
    #   generate_structure  # => "classDiagram\n    class Pizza { ... }\n"
    #
    module StructureDiagram
      # Generate the complete Mermaid classDiagram string for the domain's
      # structural model. Includes classes for aggregates, value objects,
      # and entities, plus composition and reference relationships.
      #
      # @return [String] Mermaid classDiagram source code
      def generate_structure
        lines = ["classDiagram"]

        grouped, ungrouped = partition_by_module
        grouped.each { |mod, aggs| render_module_subgraph(lines, mod, aggs) }
        ungrouped.each { |agg| render_aggregate_class(lines, agg, "    ") }

        references(lines)
        lines.join("\n")
      end

      private

      # Partition aggregates into module-grouped and ungrouped sets.
      #
      # @return [Array(Array, Array)] [grouped_pairs, ungrouped_aggs]
      def partition_by_module
        module_names = @domain.modules.flat_map(&:aggregate_names)
        ungrouped = @domain.aggregates.reject { |a| module_names.include?(a.name) }
        grouped = @domain.modules.map do |mod|
          aggs = @domain.aggregates.select { |a| mod.aggregate_names.include?(a.name) }
          [mod, aggs]
        end
        [grouped, ungrouped]
      end

      # Render a namespace subgraph wrapping module aggregates.
      #
      # @param lines [Array<String>] the diagram lines array
      # @param mod [DomainModule] the module IR node
      # @param aggs [Array<Aggregate>] aggregates in this module
      # @return [void]
      def render_module_subgraph(lines, mod, aggs)
        lines << "    namespace #{mod.name} {"
        aggs.each { |agg| render_aggregate_class(lines, agg, "        ") }
        lines << "    }"
      end

      # Render a single aggregate and its children as Mermaid classes.
      #
      # @param lines [Array<String>] the diagram lines array
      # @param agg [Aggregate] the aggregate to render
      # @param indent [String] leading whitespace
      # @return [void]
      def render_aggregate_class(lines, agg, indent)
        lines << "#{indent}class #{agg.name} {"
        agg.attributes.each { |attr| lines << "#{indent}    #{attribute_label(attr)}" }
        lines << "#{indent}}"

        agg.value_objects.each do |vo|
          lines << "#{indent}class #{vo.name} {"
          vo.attributes.each { |attr| lines << "#{indent}    #{attribute_label(attr)}" }
          lines << "#{indent}}"
          lines << "#{indent}#{agg.name} *-- #{vo.name}"
        end

        agg.entities.each do |ent|
          lines << "#{indent}class #{ent.name} {"
          lines << "#{indent}    +id : UUID"
          ent.attributes.each { |attr| lines << "#{indent}    #{attribute_label(attr)}" }
          lines << "#{indent}}"
          lines << "#{indent}#{agg.name} *-- #{ent.name}"
        end
      end

      # Format an attribute for display in a Mermaid class diagram.
      #
      # @param attr [Hecks::DomainModel::Attribute] the attribute to format
      # @return [String] Mermaid-formatted attribute line (e.g., "+String name")
      def attribute_label(attr)
        if attr.list?
          "+#{attr.type}[] #{attr.name}"
        else
          "+#{attr.type} #{attr.name}"
        end
      end

      # Add cross-aggregate reference arrows to the diagram.
      #
      # @param lines [Array<String>] the diagram lines array to append to
      # @return [void]
      def references(lines)
        @domain.aggregates.each do |agg|
          (agg.references || []).each do |ref|
            lines << "    #{agg.name} --> #{ref.type} : #{ref.name}"
          end
        end
      end
    end
  end
end
