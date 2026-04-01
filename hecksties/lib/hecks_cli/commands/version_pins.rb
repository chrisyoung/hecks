# Hecks::CLI version_pins command
#
# Lists all consumer version pins from db/hecks_versions/.pins.yml.
# Shows each consumer and the version it is pinned to.
#
#   hecks version_pins
#
Hecks::CLI.register_command(:version_pins, "List all consumer version pins") do
  pins = Hecks::DomainVersioning.all_pins(base_dir: Dir.pwd)

  if pins.empty?
    say "No version pins. Run `hecks version_pin CONSUMER --version X` to pin one.", :yellow
    next
  end

  max_name = pins.keys.map(&:length).max
  pins.each do |consumer, version|
    say "%-#{max_name}s  v%s" % [consumer, version]
  end
end
