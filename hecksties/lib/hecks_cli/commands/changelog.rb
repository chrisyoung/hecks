# Hecks::CLI changelog command
#
# Generates a Markdown changelog from tagged domain version snapshots.
# Diffs consecutive version pairs, classifies changes as breaking or
# additions, and renders structured Markdown output.
#
#   hecks changelog              # Print changelog to stdout
#   hecks changelog --output DOMAIN_CHANGELOG.md  # Write to file
#
Hecks::CLI.register_command(:changelog, "Generate domain changelog from version snapshots",
  options: {
    output: { type: :string, desc: "Write changelog to file instead of stdout" }
  }
) do
  sections = Hecks::DomainVersioning::ChangelogGenerator.call(base_dir: Dir.pwd)

  if sections.empty?
    say "No versions tagged yet. Run `hecks version_tag <version>` to tag one.", :yellow
    next
  end

  markdown = Hecks::DomainVersioning::ChangelogRenderer.render(sections)

  if options[:output]
    File.write(options[:output], markdown)
    say "Changelog written to #{options[:output]}", :green
  else
    say markdown
  end
end
