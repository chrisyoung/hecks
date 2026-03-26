# Hecksties

The core kernel of the Hecks framework — like Railties for Rails.

Provides the main `Hecks` module, boot entry points, error hierarchy, utility functions, autoload registry, and version constant. Every other component depends on this one.

## Key files

- `hecks.rb` — Main entry point (`Hecks.boot`, `Hecks.domain`, `Hecks.configure`)
- `hecks/autoloads.rb` — Lazy-load registry for all Hecks modules
- `hecks/errors.rb` — Exception hierarchy (ValidationError, GuardRejected, etc.)
- `hecks/utils.rb` — String helpers, keyword detection, block source extraction
- `hecks/smalltalk_features.rb` — Feature metadata for README generation
