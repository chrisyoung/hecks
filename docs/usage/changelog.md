# Domain Changelog Generation

Generate a Markdown changelog from tagged domain version snapshots. The changelog diffs consecutive version pairs, classifies changes as breaking or non-breaking, and renders structured output.

## Prerequisites

Tag at least two domain versions to see diffs between them:

```bash
# Tag initial version
hecks version_tag 1.0.0

# Make domain changes, then tag again
hecks version_tag 2.0.0
```

## Usage

### Print to stdout

```bash
hecks changelog
```

Output:

```markdown
# Domain Changelog

## 2.0.0 (2026-02-01)

### Breaking Changes

- - attribute: Widget.color

### Additions

- + aggregate: Gadget
- + attribute: Widget.size (String)

## 1.0.0 (2026-01-01)

Initial release.
```

### Write to file

```bash
hecks changelog --output DOMAIN_CHANGELOG.md
```

## How it works

1. Loads all version snapshots from `db/hecks_versions/`
2. Diffs each consecutive pair using `DomainDiff`
3. Classifies changes via `BreakingClassifier` (removed aggregates, attributes, commands = breaking; additions = non-breaking)
4. Renders Markdown with version headers, Breaking Changes section, and Additions section

## Programmatic API

```ruby
# Generate structured changelog data
sections = Hecks::DomainVersioning::ChangelogGenerator.call(base_dir: Dir.pwd)

sections.each do |section|
  puts "#{section[:version]} (#{section[:tagged_at]})"
  section[:breaking].each { |c| puts "  BREAKING: #{c[:label]}" }
  section[:additions].each { |c| puts "  Added: #{c[:label]}" }
end

# Render to Markdown
markdown = Hecks::DomainVersioning::ChangelogRenderer.render(sections)
File.write("DOMAIN_CHANGELOG.md", markdown)
```
