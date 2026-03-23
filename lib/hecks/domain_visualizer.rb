# Hecks::DomainVisualizer
#
# Generates Mermaid diagram strings from a domain IR. Produces a class
# diagram (structure) and a flowchart (behavior) for documentation.
#
#   Hecks::DomainVisualizer.new(domain).generate
#   Hecks::DomainVisualizer.new(domain).print
#   Hecks.visualize(domain)
#
require_relative "domain_visualizer/structure_diagram"
require_relative "domain_visualizer/behavior_diagram"

module Hecks
  class DomainVisualizer
    include StructureDiagram
    include BehaviorDiagram

    def initialize(domain)
      @domain = domain
    end

    def generate
      parts = []
      parts << "```mermaid"
      parts << generate_structure
      parts << "```"
      parts << ""
      parts << "```mermaid"
      parts << generate_behavior
      parts << "```"
      parts.join("\n")
    end

    def print
      puts generate
      nil
    end
  end
end
