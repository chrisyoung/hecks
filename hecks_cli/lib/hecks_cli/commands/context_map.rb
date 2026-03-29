Hecks::CLI.register_command(:context_map, "Show DDD context map of bounded contexts", group: "Domain Tools") do
  load_all_domains_local = lambda do
    domains_dir = File.join(Dir.pwd, "domains")
    if File.directory?(domains_dir)
      Dir[File.join(domains_dir, "*.rb")].sort.map do |path|
        eval(File.read(path), nil, path, 1)
      end
    elsif File.exist?(File.join(Dir.pwd, "hecks_domain.rb"))
      [load_domain_file(File.join(Dir.pwd, "hecks_domain.rb"))]
    else
      say "No domains/ directory or hecks_domain.rb found", :red
      []
    end
  end

  domains = load_all_domains_local.call
  next if domains.empty?

  all_policies_for = lambda do |domain|
    agg_policies = domain.aggregates.flat_map { |a| a.policies.select(&:reactive?) }
    domain_policies = domain.policies.select(&:reactive?)
    agg_policies + domain_policies
  end

  find_event_source = lambda do |doms, event_name|
    doms.each do |d|
      d.aggregates.each do |a|
        return d.name if a.events.any? { |e| e.name == event_name }
      end
    end
    "?"
  end

  find_command_target = lambda do |doms, command_name|
    doms.each do |d|
      d.aggregates.each do |a|
        return d.name if a.commands.any? { |c| c.name == command_name }
      end
    end
    "?"
  end

  derive_relationships = lambda do |doms|
    rels = []
    doms.each do |consumer|
      all_policies_for.call(consumer).each do |policy|
        source = find_event_source.call(doms, policy.event_name)
        target = find_command_target.call(doms, policy.trigger_command)
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

  find_shared_kernels = lambda do |doms, relationships|
    all_agg_to_domain = {}
    doms.each do |d|
      d.aggregates.each { |a| all_agg_to_domain[a.name] = d.name }
    end

    ref_counts = Hash.new { |h, k| h[k] = Set.new }
    doms.each do |d|
      d.aggregates.each do |agg|
        agg.attributes.each do |attr|
          next unless attr.name.to_s.end_with?("_id")
          all_agg_to_domain.each do |agg_name, owner_domain|
            next if owner_domain == d.name
            snake = domain_snake_name(agg_name)
            parts = snake.split("_")
            matched = parts.each_index.any? { |i| attr.name.to_s == parts.drop(i).join("_") + "_id" }
            ref_counts[owner_domain].add(d.name) if matched
          end
        end
      end
    end

    ref_counts.select { |_, referrers| referrers.size >= 2 }.keys
  end

  classify_pattern = lambda do |_upstream, _downstream, _shared_kernels, rels|
    if rels.any? { |r| r[:conditional] }
      "Customer-Supplier (conditional -- downstream filters events)"
    else
      "Customer-Supplier (upstream publishes, downstream reacts)"
    end
  end

  relationships = derive_relationships.call(domains)
  shared_kernels = find_shared_kernels.call(domains, relationships)

  say "Context Map", :green
  say "=" * 60
  say ""

  # Bounded Contexts
  say "Bounded Contexts:", :yellow
  domains.each do |d|
    aggs = d.aggregates.map(&:name)
    say "  [#{d.name}]"
    say "    Aggregates: #{aggs.join(', ')}"
  end
  say ""

  # Relationships
  say "Relationships:", :yellow
  pairs = relationships.group_by { |r| [r[:upstream], r[:downstream]] }
  pairs.each do |(upstream, downstream), rels|
    pattern = classify_pattern.call(upstream, downstream, shared_kernels, rels)
    events = rels.map { |r| r[:event] }.join(", ")
    cond = rels.any? { |r| r[:conditional] } ? " (conditional)" : ""

    say "  #{upstream} -> #{downstream}"
    say "    Pattern:  #{pattern}"
    say "    Events:   #{events}#{cond}"
    say ""
  end

  # Diagram
  say "Diagram:", :yellow
  say ""

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
