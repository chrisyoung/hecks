# Hecks::CLI::Domain#context_map
#
# Generates a DDD context map showing bounded context relationships:
# upstream/downstream dependencies, integration patterns, and event flows.
# Reads domains/ directory for multi-domain projects.
#
#   hecks domain context_map
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "context_map", "Show DDD context map of bounded contexts"
      def context_map
        domains = load_all_domains
        return if domains.empty?

        relationships = derive_relationships(domains)
        shared_kernels = find_shared_kernels(domains, relationships)

        say "Context Map", :green
        say "=" * 60
        say ""

        say_bounded_contexts(domains)
        say_relationships(relationships, shared_kernels)
        say_diagram(domains, relationships, shared_kernels)
      end

      private

      def derive_relationships(domains)
        rels = []
        domains.each do |consumer|
          all_policies(consumer).each do |policy|
            source = find_event_source(domains, policy.event_name)
            target = find_command_target(domains, policy.trigger_command)
            next if source == target
            next if source == "?" || target == "?"
            rels << { upstream: source, downstream: target,
                      event: policy.event_name,
                      command: policy.trigger_command,
                      conditional: !!policy.condition,
                      policy: policy.name }
          end
        end
        rels.uniq { |r| [r[:upstream], r[:downstream], r[:event]] }
      end

      def all_policies(domain)
        agg_policies = domain.aggregates.flat_map { |a| a.policies.select(&:reactive?) }
        domain_policies = domain.policies.select(&:reactive?)
        agg_policies + domain_policies
      end

      def find_shared_kernels(domains, relationships)
        # A shared kernel is referenced by ID from multiple other contexts.
        # Check if other domains' aggregates have _id attributes whose name
        # matches an aggregate in this domain (by convention).
        all_agg_to_domain = {}
        domains.each do |d|
          d.aggregates.each { |a| all_agg_to_domain[a.name] = d.name }
        end

        ref_counts = Hash.new { |h, k| h[k] = Set.new }
        domains.each do |d|
          d.aggregates.each do |agg|
            agg.attributes.each do |attr|
              next unless attr.name.to_s.end_with?("_id")
              # Match attr name to known aggregates
              all_agg_to_domain.each do |agg_name, owner_domain|
                next if owner_domain == d.name
                snake = Hecks::Utils.underscore(agg_name)
                parts = snake.split("_")
                matched = parts.each_index.any? { |i| attr.name.to_s == parts.drop(i).join("_") + "_id" }
                ref_counts[owner_domain].add(d.name) if matched
              end
            end
          end
        end

        ref_counts.select { |_, referrers| referrers.size >= 2 }.keys
      end

      def say_bounded_contexts(domains)
        say "Bounded Contexts:", :yellow
        domains.each do |d|
          aggs = d.aggregates.map(&:name)
          say "  [#{d.name}]"
          say "    Aggregates: #{aggs.join(', ')}"
        end
        say ""
      end

      def say_relationships(relationships, shared_kernels)
        say "Relationships:", :yellow

        # Group by upstream→downstream pair
        pairs = relationships.group_by { |r| [r[:upstream], r[:downstream]] }
        pairs.each do |(upstream, downstream), rels|
          pattern = classify_pattern(upstream, downstream, shared_kernels, rels)
          events = rels.map { |r| r[:event] }.join(", ")
          cond = rels.any? { |r| r[:conditional] } ? " (conditional)" : ""

          say "  #{upstream} → #{downstream}"
          say "    Pattern:  #{pattern}"
          say "    Events:   #{events}#{cond}"
          say ""
        end
      end

      def classify_pattern(upstream, downstream, shared_kernels, rels)
        if rels.any? { |r| r[:conditional] }
          "Customer-Supplier (conditional — downstream filters events)"
        else
          "Customer-Supplier (upstream publishes, downstream reacts)"
        end
      end

      def say_diagram(domains, relationships, shared_kernels)
        say "Diagram:", :yellow
        say ""

        # Build adjacency
        names = domains.map(&:name)
        max_len = names.map(&:length).max

        names.each do |name|
          outgoing = relationships.select { |r| r[:upstream] == name }
          incoming = relationships.select { |r| r[:downstream] == name }
          role = if outgoing.any? && incoming.any?
            "U/D"
          elsif outgoing.any?
            "U"
          elsif incoming.any?
            "D"
          else
            "-"
          end

          targets = outgoing.map { |r| r[:downstream] }.uniq
          arrow = targets.empty? ? "" : " ──events──► #{targets.join(', ')}"
          say "  [#{name.ljust(max_len)}] (#{role})#{arrow}"
        end

        say ""
        say "  U = Upstream, D = Downstream, U/D = Both"
      end
    end
  end
end
