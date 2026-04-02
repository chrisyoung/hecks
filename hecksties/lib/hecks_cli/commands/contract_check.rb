# Hecks::CLI -- contract_check command
#
# Compares the current domain's public API surface against a saved
# contract file. Exits non-zero when unacknowledged breaking changes
# are detected. Use --save to update the baseline contract.
#
#   hecks contract_check
#   hecks contract_check --save
#
Hecks::CLI.register_command(:contract_check, "Check for unacknowledged breaking API changes",
  options: {
    domain: { type: :string, desc: "Domain gem name or path" },
    save:   { type: :boolean, default: false, desc: "Save current API as the baseline contract" }
  }
) do
  domain = resolve_domain_option
  next unless domain

  contract_mod = Hecks::DomainVersioning::ApiContract

  if options[:save]
    path = contract_mod.save(domain, base_dir: Dir.pwd)
    say "API contract saved to #{path}", :green
    next
  end

  old_contract = contract_mod.load(base_dir: Dir.pwd)
  unless old_contract
    say "No baseline contract found. Run `hecks contract_check --save` first.", :yellow
    exit 1
  end

  new_contract = contract_mod.serialize(domain)
  changes = contract_mod.diff(old_contract, new_contract)

  if changes.empty?
    say "API contract: no changes detected.", :green
    next
  end

  classified = Hecks::DomainVersioning::BreakingClassifier.classify(changes)
  breaking = classified.select { |e| e[:breaking] }

  say "#{changes.size} API change#{"s" if changes.size != 1} detected:", :yellow
  say ""
  classified.each do |entry|
    suffix = entry[:breaking] ? "  <- BREAKING" : ""
    color = entry[:breaking] ? :red : :green
    say "  #{entry[:label]}#{suffix}", color
  end

  if breaking.any?
    say ""
    say "#{breaking.size} breaking change#{"s" if breaking.size != 1} found!", :red
    say "Run `hecks contract_check --save` to acknowledge.", :yellow
    exit 1
  end
end
