# Custom RuboCop cops

This project has custom, project-specific RuboCop cops living under
`lib/rubocop/cop/hecks/` — one file per cop, `RuboCop::Cop::Hecks::*`,
each guarding against a real bug class already found and fixed in this
codebase, so the NEXT instance of the same shape is caught mechanically
instead of by a future audit.

Each cop has a matching spec under `spec/rubocop/cop/hecks/*_spec.rb`
using `RuboCop::RSpec::ExpectOffense` (bundled with the `rubocop` gem
itself as `rubocop/rspec/support` — no extra dev dependency needed).
Those specs are ordinary RSpec examples: `bundle exec rspec
spec/rubocop/cop/hecks` runs them, and they already run as part of any
whole-suite `bundle exec rspec` / `bundle exec parallel_rspec spec`
invocation, including the ones `.github/workflows/ci.yml` already runs.
No CI change is needed to test the cops themselves.

Currently present:

- `lib/rubocop/cop/hecks/fallback_hash_lookup.rb` —
  `Hecks::FallbackHashLookup`. Flags `holder[a] || holder[b]` (the same
  receiver looked up by two different keys, falling back to the second
  when the first is falsy) — the shape behind 8+ real bugs already fixed
  one at a time across Tiers 1-5, because `||` cannot tell a genuinely
  stored `false` from a missing key. See that file's own header comment
  and `lib/hecks/query_specification/field_path.rb#read` for the `key?`
  -first idiom this codebase already converged on instead.
- `lib/rubocop/cop/hecks/thread_shared_ivar_mutation.rb` —
  `Hecks::ThreadSharedIvarMutation`. Flags plain `@ivar` mutation outside
  `initialize` on the thread-shared `Dispatcher`/`Registry` singletons.

## Wiring a cop into the real `rubocop` run (not yet done)

Right now these cops are opt-in — proven by their own specs, and
runnable ad hoc (`bundle exec rubocop --require
./lib/rubocop/cop/hecks/fallback_hash_lookup.rb --only
Hecks/FallbackHashLookup`) — but NOT yet part of the `bundle exec
rubocop` invocation `.githooks/pre-push` runs on every push, because
`.rubocop.yml` doesn't `require` them yet. Wiring one in is two small
additions to `.rubocop.yml`:

```yaml
# alongside the existing `plugins:` key
require:
  - ./lib/rubocop/cop/hecks/fallback_hash_lookup
  - ./lib/rubocop/cop/hecks/thread_shared_ivar_mutation

# a normal cop config stanza, same shape as any other cop in this file
Hecks/FallbackHashLookup:
  Enabled: true
Hecks/ThreadSharedIvarMutation:
  Enabled: true
```

`require:` (a plain file require) and `plugins:` (the newer
lint-roller plugin API `rubocop-rspec` 3.x uses) coexist fine in the
same `.rubocop.yml` — they are independent RuboCop config keys.

Left undone here deliberately: `.rubocop.yml` is a single shared file
several cops are landing custom rules into around the same time: a
single agent editing it removes the others' in-flight cops in a
conflicting merge. Wiring both `require:` entries and both cop stanzas
in one pass, once every custom cop for this effort has landed, avoids
that. Once wired, no further CI change is needed either —
`.github/workflows/ci.yml` doesn't run `rubocop` itself today (only
`.githooks/pre-push` does); if CI ever grows a `rubocop` job, it needs
nothing custom cop-specific, just the same `bundle exec rubocop -c
.rubocop.yml` the pre-push hook already runs, which picks up whatever
`.rubocop.yml` requires.

## A note on `bundle exec rubocop --only Hecks/FallbackHashLookup` today

Running the cop against the whole tree ahead of wiring
(`bundle exec rubocop --require
./lib/rubocop/cop/hecks/fallback_hash_lookup.rb --only
Hecks/FallbackHashLookup`) finds real, PRE-EXISTING instances of this
shape that were never part of the Tiers 1-5 fix set — mostly
`settings[:key] || settings["key"]` in the storage adapters (`d1.rb`,
`heki.rb`, `lambda.rb`, `postgres.rb`, `sqlite.rb`, the era plugin's
`postgres_era.rb` and `era_resolver.rb`), plus a handful of one-off
spots (`bin/fuzz`, `lib/hecks/bluebook/dsl/word_gate.rb`,
`lib/hecks/facade/cli_door.rb`, and a few specs reading fixture hashes
by either-spelling key). Fixing those is out of scope for the cop
itself — flagged here for a follow-up pass, not silently patched.
