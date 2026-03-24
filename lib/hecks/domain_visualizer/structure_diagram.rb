# Hecks::DomainVisualizer::StructureDiagram
#
# Builds the Mermaid classDiagram portion showing aggregates, attributes,
# value objects, and inter-aggregate references.
#
#   include StructureDiagram
#   generate_structure  # => "classDiagram\n    class Pizza { ... }\n"
#
module Hecks
  class DomainVisualizer
    module StructureDiagram
      private

      def generate_structure
        lines = ["classDiagram"]

        @domain.aggregates.each do |agg|
          lines << "    class #{agg.name} {"
          agg.attributes.each do |attr|
            lines << "        #{attribute_label(attr)}"
          end
          lines << "    }"

          agg.value_objects.each do |vo|
            lines << "    class #{vo.name} {"
            vo.attributes.each do |attr|
              lines << "        #{attribute_label(attr)}"
            end
            lines << "    }"
            lines << "    #{agg.name} *-- #{vo.name}"
          end

          agg.entities.each do |ent|
            lines << "    class #{ent.name} {"
            lines << "        +id : UUID"
            ent.attributes.each do |attr|
              lines << "        #{attribute_label(attr)}"
            end
            lines << "    }"
            lines << "    #{agg.name} *-- #{ent.name}"
          end
        end

        references(lines)
        lines.join("\n")
      end

      def attribute_label(attr)
        if attr.list?
          "+#{attr.type}[] #{attr.name}"
        elsif attr.reference?
          "+String #{attr.name}"
        else
          "+#{attr.type} #{attr.name}"
        end
      end

      def references(lines)
        @domain.aggregates.each do |agg|
          agg.attributes.select(&:reference?).each do |attr|
            lines << "    #{agg.name} --> #{attr.type} : references"
          end
        end
      end
    end
  end
end
