require "hecks"
require "hecks_multidomain"
require "hecks_features"

# Boot all domains
apps = Hecks.boot(__dir__)

# --- Vertical Slice Analysis ---
# Governance uses cross-domain reactive policies (event bus between bounded
# contexts), so intra-domain slices are empty. Slices shine in domains with
# internal reactive chains — see examples/banking for a demo.
puts "\n=== Vertical Slices ==="
Dir[File.join(__dir__, "domains", "*.rb")].sort.each do |f|
  load f
  domain = Hecks.last_domain
  slices = domain.slices

  if slices.empty?
    policies = domain.reactive_policies
    if policies.any?
      puts "\n#{domain.name}: #{policies.size} cross-domain reactive policies (no intra-domain slices)"
      policies.each do |p|
        puts "  #{p.name}: #{p.event_name} -> #{p.trigger_command}"
      end
    end
  else
    puts "\n#{domain.name}:"
    slices.each do |slice|
      cross = slice.cross_aggregate? ? " [cross-aggregate]" : ""
      puts "  #{slice.name}#{cross}"
      puts "    #{slice.commands.join(' -> ')}"
    end
  end
end
