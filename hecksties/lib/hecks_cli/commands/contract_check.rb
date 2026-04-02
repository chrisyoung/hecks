# Hecks CLI: contract_check
#
# Compare the current domain's API contract against a saved baseline.
# Shows added/removed aggregates, attributes, and commands.
#
#   hecks contract_check
#   hecks contract_check --save
#
Hecks::CLI.register_command(:contract_check, "Compare domain API contract against baseline",
  options: {
    save: { type: :boolean, desc: "Save current contract as baseline" }
  }
) do
  require "hecks/domain_versioning/api_contract"

  domain = resolve_domain_option
  next unless domain

  contract_path = File.join(Dir.pwd, "api_contract.json")

  if options[:save]
    contract = Hecks::DomainVersioning::ApiContract.serialize(domain)
    File.write(contract_path, JSON.pretty_generate(contract) + "\n")
    say "Saved API contract to #{contract_path}", :green
    next
  end

  unless File.exist?(contract_path)
    say "No baseline found. Run `hecks contract_check --save` first.", :yellow
    next
  end

  old_contract = JSON.parse(File.read(contract_path), symbolize_names: true)
  new_contract = Hecks::DomainVersioning::ApiContract.serialize(domain)
  diffs = Hecks::DomainVersioning::ApiContract.diff(old_contract, new_contract)

  if diffs.empty?
    say "API contract unchanged.", :green
    next
  end

  say "#{diffs.size} contract difference#{"s" if diffs.size != 1}:", :yellow
  diffs.each do |d|
    breaking = d[:type].to_s.start_with?("removed")
    color = breaking ? :red : :green
    prefix = breaking ? "-" : "+"
    say "  #{prefix} #{d[:type]}: #{d[:detail]}", color
  end

  removals = diffs.count { |d| d[:type].to_s.start_with?("removed") }
  say "\n#{removals} breaking change#{"s" if removals != 1}!", :red if removals > 0
end
