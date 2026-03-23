# Hecks::DomainVisualizerMethods
#
# Top-level entry point for Mermaid diagram generation.
#
#   Hecks.visualize(domain)  # => "```mermaid\nclassDiagram\n..."
#
module Hecks
  module DomainVisualizerMethods
    def visualize(domain)
      DomainVisualizer.new(domain).generate
    end
  end
end
