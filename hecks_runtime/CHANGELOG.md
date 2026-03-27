# Changelog

## 0.1.0 (Unreleased)

- Initial release as a standalone component

### 2026-03-27

- `hecks_filesystem_store` extension — JSON file persistence, auto-wires at boot
- `hecks_validations` extension — server-side parameter validation from domain rules
- `hecks_web_explorer` extension — ERB-based domain UI (layout, index, show, form, config)
- `Hecks::WebExplorer::Renderer` — ERB rendering with layout wrapping
- `Hecks::FilesystemRepository` — JSON files in `data/<aggregate>s/<uuid>.json`
