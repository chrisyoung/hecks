# Antibody: no new non-bluebook code

`bin/antibody-check` fails a commit or PR that adds **or modifies** any
file whose extension (or shebang) marks it as code-that-should-be-bluebook.

## Why

Bluebook is the source AND the thing that runs. `hecks-life` dispatches
bluebook directly — no compile step, no generated artifacts. Bluebook is
Turing complete and more readable than anything else in the repo.

Therefore: every non-bluebook file in this repo is a gap.

- **Code** (`rb`, `rs`, `py`, `sh`, `js`, `ts`, `go`, `html`, `css`) → should
  be an aggregate + commands in a bluebook, dispatched by the runtime.
- **Config-as-data** (`yml`, `yaml`) → should be a `.fixtures` file.
- **OS adapter** (shell-out, git, fs, network) → should be a `.hecksagon`
  file describing the adapter declaratively.

The terminal state: `bin/` contains `.bluebook` files with
`#!/usr/bin/env hecks-life run` shebangs. No wrappers, no glue.

## What the check does

Diffs the current branch against a base (default `origin/main`) and
lists every **added or modified** file that matches a flagged extension
or shebang. Running `bin/antibody-check` by itself is safe — it reads,
doesn't write.

```
⚠ antibody: 2 non-bluebook file(s) touched
    lib/hecks/runtime/something.rb
    config/routes.yml

  Bluebook is the source AND the thing that runs.
  ...
```

Extensionless binaries are classified by shebang (`ruby`, `bash`, `sh`,
`python`, `node`). Unknown shebangs fall through as non-code.

## Where it runs

- **Pre-commit hook (`bin/git-hooks/pre-commit`, Gate 5):** advisory.
  Warns on commit; does not block. Local work stays unobstructed.
- **CI (`.github/workflows/antibody.yml`):** blocking. Every PR must
  either touch no non-bluebook files or carry an exemption.

## Exemption

Put `[antibody-exempt: <reason>]` in any commit message on the branch.
The reason is captured in the hook output and on the PR, so the gap is
explicitly named and searchable.

Examples:

```
fix: correct parity drift in nursery section

[antibody-exempt: thin shell wrapper calling hecks-life parity]
```

```
feat: Modal training config

[antibody-exempt: external Python dep — Modal/MLX ecosystem, tracked in i37]
```

**There are no permanent exemptions.** No allowlist file, no repo-wide
carve-outs, no grandfathered paths. Every PR that touches a non-bluebook
file supplies its own justification. The next time someone edits the
same file, the same question is asked again — because the gap is still
there.

## Follow-up path

The antibody is transitional. The real win is:

1. `hecks-life run <file.bluebook>` as a stable entry point.
2. `#!/usr/bin/env hecks-life run` shebang so bluebooks are directly
   executable scripts.
3. `.hecksagon` adapters declare shell-out / git / fs / network
   surfaces in the same native DSL.
4. `bin/*.bluebook` files replace every existing `bin/*` wrapper.
5. `lib/` shrinks toward zero as capabilities move into bluebooks +
   hecksagons.

Once that's in place, the antibody stops counting exemptions and starts
counting how many non-bluebook files are left in the repo. Zero is the
target.
