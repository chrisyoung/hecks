# Hecks CLI: changelog
#
# Generate a Markdown domain changelog from tagged version snapshots.
# Compares consecutive versions and classifies changes as breaking or
# non-breaking.
#
#   hecks changelog
#   hecks changelog --output DOMAIN_CHANGELOG.md
#
Hecks::CLI.register_command(:changelog, "Generate domain changelog from version diffs",
  options: {
    output: { type: :string, desc: "Output file path (default: stdout)" }
  }
) do
  require "hecks/domain_versioning/changelog_generator"

  md = Hecks::DomainVersioning::ChangelogGenerator.generate(base_dir: Dir.pwd)

  if options[:output]
    File.write(options[:output], md)
    say "Wrote changelog to #{options[:output]}", :green
  else
    say md
  end
end
