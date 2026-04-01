# Hecks::CLI version_pin command
#
# Pins a consumer to a specific tagged domain version. The pin is stored
# in db/hecks_versions/.pins.yml. Validates the version exists before pinning.
#
#   hecks version_pin billing-service --version 2.1.0
#
Hecks::CLI.register_command(:version_pin, "Pin a consumer to a tagged domain version",
  args: ["CONSUMER"],
  options: {
    version: { type: :string, desc: "Version to pin to (required)", required: true }
  }
) do |consumer|
  version = options[:version]

  unless Hecks::DomainVersioning.exists?(version, base_dir: Dir.pwd)
    say "Version #{version} does not exist. Tag it first with `hecks version_tag #{version}`.", :red
    next
  end

  Hecks::DomainVersioning.pin(consumer, version, base_dir: Dir.pwd)
  say "Pinned #{consumer} to v#{version}", :green
end
