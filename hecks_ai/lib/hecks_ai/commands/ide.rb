Hecks::CLI.register_command(:ide, "Launch browser IDE with Claude Code and context panel",
  args: ["PORT"]
) do |port = 3001|
  local = File.expand_path("../../../../bin/hecks_ide", __dir__)
  script = File.exist?(local) ? local : ::Gem.bin_path("hecks", "hecks_ide")
  exec script, port.to_s
rescue ::Gem::Exception
  say "hecks_ide not found. Is the hecks gem installed?", :red
end
