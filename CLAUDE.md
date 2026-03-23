# CLAUDE.md

## Before every commit

1. **Update docs** — sync all file doc headers and READMEs with current features
2. **Run specs** — `bundle exec rspec --order defined` (280+ specs, all must pass)
3. **Check file sizes** — no file over 200 lines (`find lib -name "*.rb" -exec wc -l {} + | sort -rn | head -5`)
4. **Smoke test** — `ruby -Ilib examples/pizzas/app.rb`
5. **Stage specifically** — don't `git add -A`, stage specific files to avoid Rails boilerplate leaking in
6. **Update .gitignore** if new generated/temp files appear

## .gitignore reminders

The `examples/rails_app/` has Rails-generated files that should NOT be committed:
- `bin/`, `public/`, `vendor/`, `lib/tasks/`, `.github/`, `.rubocop.yml`, `.ruby-version`
- `db/schema.rb`, `db/seeds.rb`, `log/`, `tmp/`, `storage/`
- Only commit: `app/`, `config/`, `db/migrate/`, `Gemfile`, `Rakefile`, `config.ru`, `README.md`

## Issue tracking

- Always use Linear for tracking work — create issues before starting, update status as you go
- Use the Linear MCP tools (list_issues, save_issue, etc.) to manage issues
- Tag issues with appropriate labels (e.g. "Repository")
- Mark issues Done when the work is committed and pushed

## Project conventions

- Every lib file has a doc comment header: class name, one-line purpose, architecture context, usage example
- No file over 200 lines — extract modules/classes if approaching the limit
- Tests run against memory adapters — fast and isolated
- CalVer versioning (YYYY.MM.DD.N) — no manual bumping
- `Hecks.configure` for Rails, `Application.new` for plain Ruby
- Domain objects feel like Ruby — `Pizza.create`, `Pizza.find`, `pizza.toppings.create`
