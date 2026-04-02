# Hecks::CLI -- concerns command
#
# Lists all active concerns (world + custom) for a domain, shows their
# status, and reports any violations from custom concern rules.
#
#   hecks concerns
#   hecks concerns --domain path/to/domain
#
Hecks::CLI.register_command(:concerns, "List active concerns (world + custom)",
  options: {
    domain: { type: :string, desc: "Domain gem name or path" }
  }
) do
  domain = resolve_domain_option
  next unless domain

  world = domain.world_concerns
  custom = domain.respond_to?(:custom_concerns) ? domain.custom_concerns : []

  if world.empty? && custom.empty?
    say "No concerns declared for #{domain.name}", :yellow
    next
  end

  say "Concerns for #{domain.name}:", :bold
  say ""

  if world.any?
    say "World Concerns:", :green
    world.each { |c| say "  [world] :#{c}" }
    say ""
  end

  if custom.any?
    say "Custom Concerns:", :green
    custom.each do |name|
      concern = Hecks.find_concern(name)
      if concern
        say "  [custom] :#{name} -- #{concern.description}"
        concern.required_extensions.each do |ext|
          say "    requires: :#{ext}"
        end
        concern.rules.each do |rule|
          say "    rule: #{rule.name}"
        end
      else
        say "  [custom] :#{name} (not registered)", :red
      end
    end
    say ""
  end

  # Run validation and show results
  validator = Hecks::Validator.new(domain)
  validator.valid?

  print_world_concerns_report(validator)

  custom_errors = validator.errors.select { |e| e.to_s.start_with?("CustomConcern") }
  if custom_errors.any?
    say ""
    say "Custom Concern Violations:", :red
    custom_errors.each { |e| say "  - #{e}", :red }
  elsif custom.any?
    say "Custom concerns: all rules passing", :green
  end
end
