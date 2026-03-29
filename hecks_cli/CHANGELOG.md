# Changelog

## 0.1.0 (Unreleased)

- Initial release as a standalone component

### 2026-03-28

- `hecks domain promote AGGREGATE` — extract aggregate into its own domain
- Fix `version --domain`: `::Gem.loaded_specs` instead of shadowed `Gem`
- 16 CLI command integration tests

### 2026-03-27

- `hecks domain build --static` — generate self-contained Ruby project
- `hecks domain serve --static` — build and serve with built-in UI
- Extract GemBuilder from `hecks gem` command for multi-component build/install
- Add `hecks claude` command to start watchers and launch Claude Code
- Add hecks_watchers to GemBuilder COMPONENTS list
