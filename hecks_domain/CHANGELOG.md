# Changelog

## 0.1.0 (Unreleased)

- Initial release as a standalone component

### 2026-03-28

- Unified `extend` API replaces `persist_to`, `listens_to`, `sends_to`, `extend_with`
- CQRS named connections via `extend :sqlite, as: :write`
- ReadmeGenerator falls back to `hecks_docs/` when `docs/` doesn't exist

### 2026-03-27

- `Hecks.build_go(domain)` — generates Go projects from the domain IR
- `Hecks.build_static(domain)` — generates self-contained Ruby projects
- Automatic smoke test after `build_go` and `build_static` — starts server, exercises all pages/forms, verifies no render errors
- Command generator uses `#{domain_module}::Error` instead of `Hecks::Error` — static output has no hecks dependency
- `Utils.underscore` handles Symbol input
- Structured `ValidationError` with `field:` and `rule:` kwargs in generated code
- `mixin_prefix:` parameter on generators for static output namespacing
- VO-aware list append in command constructors (create and update)
- `aggregate_autoloads` helper on AutoloadGenerator
