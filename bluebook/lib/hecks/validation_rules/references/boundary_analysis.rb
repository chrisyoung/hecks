# Hecks::ValidationRules::References::BoundaryAnalysis
#
# Detects "Big Ball of Mud" anti-patterns by analyzing the reference graph
# across aggregates. Three checks:
#
# 1. **Reference density** -- ratio of total references to aggregate count.
#    A density above 2.0 suggests excessive coupling between boundaries.
# 2. **Hub detection** -- any aggregate that is the target of more than 50%
#    of all references is a hub, indicating a God Object smell.
# 3. **Cycle detection** -- DFS-based detection of circular reference chains
#    (A -> B -> C -> A). Cycles make it impossible to reason about boundaries.
#
# All findings are warnings (non-blocking), not errors.
#
#   rule = BoundaryAnalysis.new(domain)
#   rule.errors   # => []
#   rule.warnings # => ["Reference density 2.5 exceeds threshold ..."]
#
module Hecks
  module ValidationRules
    module References
      class BoundaryAnalysis < BaseRule
        DENSITY_THRESHOLD = 2.0
        HUB_THRESHOLD     = 0.5

        def errors
          []
        end

        def warnings
          return [] if @domain.aggregates.size < 2

          graph = build_graph
          results = []
          results.concat(density_warnings(graph))
          results.concat(hub_warnings(graph))
          results.concat(cycle_warnings(graph))
          results
        end

        private

        def build_graph
          graph = {}
          @domain.aggregates.each do |agg|
            targets = (agg.references || []).reject(&:domain).map { |r| r.type.to_s }
            graph[agg.name] = targets
          end
          graph
        end

        def density_warnings(graph)
          total_refs = graph.values.sum(&:size)
          agg_count  = graph.size
          density    = total_refs.to_f / agg_count

          return [] unless density > DENSITY_THRESHOLD

          ["Reference density #{format('%.1f', density)} exceeds threshold #{DENSITY_THRESHOLD} " \
           "(#{total_refs} references across #{agg_count} aggregates). " \
           "Consider splitting into separate bounded contexts."]
        end

        def hub_warnings(graph)
          total_refs = graph.values.sum(&:size)
          return [] if total_refs.zero?

          inbound = Hash.new(0)
          graph.each_value do |targets|
            targets.each { |t| inbound[t] += 1 }
          end

          inbound.filter_map do |name, count|
            pct = count.to_f / total_refs
            next unless pct > HUB_THRESHOLD

            "#{name} is a hub aggregate -- referenced by #{format('%.0f', pct * 100)}% " \
            "of all references (#{count}/#{total_refs}). Consider extracting a shared kernel " \
            "or anti-corruption layer."
          end
        end

        def cycle_warnings(graph)
          cycles = detect_cycles(graph)
          cycles.map do |cycle|
            path = cycle.join(" -> ") + " -> #{cycle.first}"
            "Reference cycle detected: #{path}. " \
            "Break the cycle with a domain event or policy instead of a direct reference."
          end
        end

        def detect_cycles(graph)
          visited  = {}
          on_stack = {}
          stack    = []
          cycles   = []

          graph.each_key do |node|
            next if visited[node]
            dfs(node, graph, visited, on_stack, stack, cycles)
          end

          cycles.map { |c| c.sort }.uniq
        end

        def dfs(node, graph, visited, on_stack, stack, cycles)
          visited[node]  = true
          on_stack[node] = true
          stack.push(node)

          (graph[node] || []).each do |neighbor|
            next unless graph.key?(neighbor)

            if on_stack[neighbor]
              cycle_start = stack.index(neighbor)
              cycles << stack[cycle_start..].dup
            elsif !visited[neighbor]
              dfs(neighbor, graph, visited, on_stack, stack, cycles)
            end
          end

          stack.pop
          on_stack[node] = false
        end
      end
      Hecks.register_validation_rule(BoundaryAnalysis)
    end
  end
end
