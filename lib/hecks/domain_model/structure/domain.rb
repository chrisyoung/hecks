# Hecks::DomainModel::Structure::Domain
#
# The root of the domain model intermediate representation. A domain holds
# aggregates and provides helpers for naming (module_name, gem_name),
# introspection (describe), glossary output (glossary), and Mermaid
# visualization (to_mermaid, visualize).
#
# Part of the DomainModel IR layer. Built by DomainBuilder, consumed by every
# generator and by the Application/Session at runtime.
#
#   domain = Domain.new(name: "Pizzas", aggregates: [pizza_agg, order_agg])
#   domain.gem_name    # => "pizzas_domain"
#   domain.describe    # prints aggregate tree with commands, queries, policies
#   domain.glossary    # prints domain term glossary
#   domain.visualize   # prints Mermaid diagrams (structure + behavior)
#
module Hecks
  module DomainModel
    module Structure
    class Domain
      attr_reader :name, :aggregates, :custom_verbs
      attr_accessor :source_path

      def initialize(name:, aggregates: [], custom_verbs: [])
        @name = name
        @aggregates = aggregates
        @custom_verbs = custom_verbs
      end

      def module_name
        Hecks::Utils.sanitize_constant(name)
      end

      def gem_name
        Hecks::Utils.underscore(module_name) + "_domain"
      end

      def describe
        lines = [name, ""]
        aggregates.each do |agg|
          attrs = agg.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
          lines << "  #{agg.name} (#{attrs})"
          agg.commands.each_with_index do |cmd, i|
            event = agg.events[i]
            cmd_attrs = cmd.attributes.map { |a| "#{a.name}: #{Hecks::Utils.type_label(a)}" }.join(", ")
            lines << "    #{cmd.name}(#{cmd_attrs}) -> #{event&.name}"
          end
          agg.queries.each { |q| lines << "    query: #{q.name}" }
          agg.policies.each do |pol|
            async_label = pol.async ? " [async]" : ""
            lines << "    policy: #{pol.name} (#{pol.event_name} -> #{pol.trigger_command})#{async_label}"
          end
        end
        puts lines.join("\n")
        nil
      end
      def glossary
        Hecks::DomainGlossary.new(self).print
      end

      def to_mermaid
        Hecks::DomainVisualizer.new(self).generate
      end

      def visualize
        Hecks::DomainVisualizer.new(self).print
      end
    end
    end
  end
end
