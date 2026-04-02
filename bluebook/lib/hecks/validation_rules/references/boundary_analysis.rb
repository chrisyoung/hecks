module Hecks
  module ValidationRules
    module References

    # Hecks::ValidationRules::References::BoundaryAnalysis
    #
    # Advisory warnings for aggregate reference topology: density, hub
    # aggregates, and reference cycles. Dense reference graphs indicate
    # weak aggregate boundaries. Hub aggregates referenced by many others
    # may need an anti-corruption layer. Cycles make it impossible to
    # determine a clean dependency order.
    #
    # Part of the ValidationRules::References group -- run by +Hecks.validate+.
    #
    # Checks:
    # - Reference density above 0.5 (edges / max possible edges)
    # - Hub aggregates referenced by 3+ other aggregates
    # - Reference cycles detected via DFS
    class BoundaryAnalysis < BaseRule
      DENSITY_THRESHOLD = 0.5
      HUB_THRESHOLD     = 3

      # Returns no errors. This rule only produces warnings.
      #
      # @return [Array<String>] always empty
      def errors
        []
      end

      # Returns warnings for high density, hub aggregates, and cycles.
      #
      # @return [Array<ValidationMessage>] warning messages
      def warnings
        graph = build_graph
        return [] if graph.empty?

        result = []
        result.concat(check_density(graph))
        result.concat(check_hubs(graph))
        result.concat(check_cycles(graph))
        result
      end

      private

      def build_graph
        graph = {}
        @domain.aggregates.each do |agg|
          targets = (agg.references || []).map { |r| r.type.to_s }
          graph[agg.name] = targets
        end
        graph
      end

      def check_density(graph)
        n = graph.size
        return [] if n < 2
        edges = graph.values.sum(&:size)
        max_edges = n * (n - 1)
        density = edges.to_f / max_edges
        return [] if density <= DENSITY_THRESHOLD

        [error("Reference density is #{"%.2f" % density} (#{edges}/#{max_edges} possible edges)",
          hint: "High density indicates weak aggregate boundaries -- consider merging or introducing anti-corruption layers")]
      end

      def check_hubs(graph)
        inbound = Hash.new(0)
        graph.each_value do |targets|
          targets.each { |t| inbound[t] += 1 }
        end

        inbound.filter_map do |name, count|
          next unless count >= HUB_THRESHOLD
          error("#{name} is a hub aggregate (referenced by #{count} others)",
            hint: "Consider an anti-corruption layer or splitting #{name}")
        end
      end

      def check_cycles(graph)
        visited = {}
        on_stack = {}
        cycles = []

        graph.each_key do |node|
          next if visited[node]
          dfs(node, graph, visited, on_stack, [], cycles)
        end

        cycles.map do |cycle|
          path = cycle.join(" -> ")
          error("Reference cycle: #{path}",
            hint: "Break the cycle by removing one reference or using a domain event instead")
        end
      end

      def dfs(node, graph, visited, on_stack, path, cycles)
        visited[node] = true
        on_stack[node] = true
        path.push(node)

        (graph[node] || []).each do |neighbor|
          next unless graph.key?(neighbor)
          if on_stack[neighbor]
            cycle_start = path.index(neighbor)
            cycles << path[cycle_start..] + [neighbor] if cycle_start
          elsif !visited[neighbor]
            dfs(neighbor, graph, visited, on_stack, path, cycles)
          end
        end

        path.pop
        on_stack[node] = false
      end
    end
    Hecks.register_validation_rule(BoundaryAnalysis)
    end
  end
end
