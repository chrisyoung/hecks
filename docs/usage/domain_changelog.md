# Domain Changelog

Generate a Markdown changelog from domain version snapshots. Each
consecutive version pair is diffed, and changes are classified as
breaking or non-breaking.

## CLI Usage

```bash
# Print to stdout
hecks changelog

# Write to file
hecks changelog --output DOMAIN_CHANGELOG.md
```

## Output Format

```markdown
## 2.0.0
_Tagged: 2026-04-01_

### Breaking Changes

- - attribute: Pizza.calories

### Changes

- + attribute: Pizza.size
- + command: Pizza.ResizePizza
```

## Programmatic Usage

```ruby
# Full changelog from version history
md = Hecks::DomainVersioning::ChangelogGenerator.generate(base_dir: Dir.pwd)

# Single version diff
md = Hecks::DomainVersioning::ChangelogGenerator.generate_diff(
  old_domain, new_domain, version: "2.0.0"
)
```

## Prerequisites

Tag versions with `hecks version_tag` before generating changelogs.
The generator compares consecutive snapshots stored in `db/hecks_versions/`.
