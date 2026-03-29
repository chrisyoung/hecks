Hecks::CLI.register_command(:diff, "Show changes since last build", group: "Core",
  options: {
    domain:  { type: :string, desc: "Domain gem name or path" },
    version: { type: :string, desc: "Domain version" }
  }
) do
  domain = resolve_domain_option
  next unless domain

  snapshot_path = Hecks::Migrations::DomainSnapshot::DEFAULT_PATH
  unless Hecks::Migrations::DomainSnapshot.exists?(path: snapshot_path)
    say "No snapshot found. Run `hecks build` first to create a baseline.", :yellow
    next
  end

  old_domain = Hecks::Migrations::DomainSnapshot.load(path: snapshot_path)
  changes = Hecks::Migrations::DomainDiff.call(old_domain, domain)

  if changes.empty?
    say "No changes detected.", :green
    next
  end

  format_change = lambda do |change|
    case change.kind
    when :add_aggregate       then "+ Added aggregate: #{change.aggregate}"
    when :remove_aggregate    then "- Removed aggregate: #{change.aggregate}"
    when :add_attribute       then "+ Added attribute: #{change.aggregate}.#{change.details[:name]}"
    when :remove_attribute    then "- Removed attribute: #{change.aggregate}.#{change.details[:name]}"
    when :add_command         then "+ Added command: #{change.details[:name]}"
    when :remove_command      then "- Removed command: #{change.details[:name]}"
    when :add_policy          then "+ Added policy: #{change.details[:name]}"
    when :remove_policy       then "- Removed policy: #{change.details[:name]}"
    when :change_policy       then "~ Changed policy: #{change.details[:name]}"
    when :add_validation      then "+ Added validation: #{change.aggregate}.#{change.details[:field]}"
    when :remove_validation   then "- Removed validation: #{change.aggregate}.#{change.details[:field]}"
    when :add_value_object    then "+ Added value object: #{change.details[:name]}"
    when :remove_value_object then "- Removed value object: #{change.details[:name]}"
    when :add_entity          then "+ Added entity: #{change.details[:name]}"
    when :remove_entity       then "- Removed entity: #{change.details[:name]}"
    when :add_query           then "+ Added query: #{change.details[:name]}"
    when :remove_query        then "- Removed query: #{change.details[:name]}"
    when :add_scope           then "+ Added scope: #{change.details[:name]}"
    when :remove_scope        then "- Removed scope: #{change.details[:name]}"
    when :add_specification   then "+ Added specification: #{change.details[:name]}"
    when :remove_specification then "- Removed specification: #{change.details[:name]}"
    else "#{change.kind}: #{change.aggregate} #{change.details}"
    end
  end

  breaking_kinds = %i[remove_aggregate remove_attribute remove_command remove_value_object remove_entity]

  say "#{changes.size} change#{"s" if changes.size != 1} detected:", :yellow
  say ""

  changes.each do |change|
    label = format_change.call(change)
    color = breaking_kinds.include?(change.kind) ? :red : :green
    say "  #{label}", color
  end

  breaking = changes.count { |c| breaking_kinds.include?(c.kind) }
  if breaking > 0
    say ""
    say "#{breaking} breaking change#{"s" if breaking != 1}!", :red
  end
end
