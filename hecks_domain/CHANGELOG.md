# Changelog

## 0.1.0 (Unreleased)

- Initial release as a standalone component

### 2026-03-27

- `Hecks.build_go(domain)` — generates Go projects from the domain IR
- `Hecks.build_static(domain)` — generates self-contained Ruby projects
- Structured `ValidationError` with `field:` and `rule:` kwargs in generated code
- `mixin_prefix:` parameter on generators for static output namespacing
- VO-aware list append in command constructors (create and update)
- `aggregate_autoloads` helper on AutoloadGenerator
