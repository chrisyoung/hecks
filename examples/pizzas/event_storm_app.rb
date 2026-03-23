#!/usr/bin/env ruby
#
# Example: Building a domain from an Event Storm document
#
# Shows how Hecks.from_event_storm parses event storm documents (ASCII or YAML)
# and produces both a Domain object and an editable Ruby DSL file.
#
# Run from the hecks project root:
#   ruby -Ilib examples/pizzas/event_storm_app.rb          # ASCII format
#   ruby -Ilib examples/pizzas/event_storm_app.rb yaml     # YAML format

require "hecks"

# 1. Parse the event storm document (ASCII or YAML)
format = ARGV[0] == "yaml" ? "yml" : "md"
storm_path = File.join(__dir__, "event_storm.#{format}")
puts "Reading: #{storm_path}"
puts
result = Hecks.from_event_storm(storm_path, name: "PizzaOrdering")

# 2. Show what was discovered
puts "=== Domain: #{result.domain.name} ==="
puts

result.domain.aggregates.each do |agg|
  next if agg.commands.empty? && agg.policies.empty?
  puts "Aggregate: #{agg.name}"

  agg.commands.each do |cmd|
    extras = []
    extras << "reads: #{cmd.read_models.map(&:name).join(', ')}" unless cmd.read_models.empty?
    extras << "calls: #{cmd.external_systems.map(&:name).join(', ')}" unless cmd.external_systems.empty?
    suffix = extras.empty? ? "" : " (#{extras.join('; ')})"
    puts "  Command: #{cmd.name}#{suffix}"
  end

  agg.events.each do |evt|
    puts "  Event:   #{evt.name}"
  end

  agg.policies.each do |pol|
    puts "  Policy:  #{pol.name} — on #{pol.event_name} -> #{pol.trigger_command}"
  end
  puts
end

# 3. Show warnings (event names that don't match Hecks conventions)
unless result.warnings.empty?
  puts "=== Warnings ==="
  result.warnings.uniq.each { |w| puts "  #{w}" }
  puts
end

# 4. Write the generated DSL to a file
dsl_path = File.join(__dir__, "event_storm_domain.rb")
File.write(dsl_path, result.dsl)
puts "=== Generated DSL written to: #{dsl_path} ==="
puts
puts result.dsl

# 5. Prove the generated DSL is valid Ruby that Hecks can evaluate
domain = eval(result.dsl)
puts "=== Round-trip check ==="
puts "Parsed domain: #{domain.name}"
puts "Aggregates: #{domain.aggregates.map(&:name).join(', ')}"
puts "Aggregates: #{domain.aggregates.map(&:name).join(', ')}"
