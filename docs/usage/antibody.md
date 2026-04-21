# Antibody: no new non-bluebook code

`bin/antibody-check` fails a commit or PR that adds **or modifies** any
file written in a language that isn't part of the Hecks source vocabulary.

## The vocabulary

Five file types. That's all.

| Extension | What it declares |
|---|---|
| `.bluebook` | domains, aggregates, commands, events, policies |
| `.hecksagon` | adapters — shell-out, git, fs, network, DB |
| `.fixtures` | data (replaces yaml/json config) |
| `.behaviors` | behavioral tests |
| `.world` | world / environment declarations |

`hecks-life` parses and dispatches all five natively. There is no
compile step and there are no generated artifacts.

## Why

No Ruby. No Rust. No Python. No shell. Everything the system does is
expressed in the five DSLs above. Bluebook is Turing complete and more
readable than anything else in the repo.

Every file *not* in the five DSLs is a gap — either the concept should
be re-expressed in one of them, or the runtime needs to grow so it can.

The terminal state: `bin/` contains `.bluebook` files with
`#!/usr/bin/env hecks-life run` shebangs. `lib/` shrinks toward zero.
Shell-out, git calls, filesystem, network — all `.hecksagon` adapters.

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

`EXEMPTIONS.md` in the repo root is the running ledger of known
categories and why they exist today. Use a category name as the reason
when it fits — treat the free-text form as a last resort:

```
fix: patch command bus so saga steps retry on transient errors

[antibody-exempt: runtime:ruby]
```

```
feat: nursery viability stats script

[antibody-exempt: tool:audit]
```

Current categories (see `EXEMPTIONS.md` for the full entries):

| Category | Lives where | Arc |
|---|---|---|
| `runtime:ruby` | `lib/hecks/**` | Stays — better than Rust for business operations |
| `runtime:rust` | `hecks_life/**` | Becomes a binary that Ruby wraps |
| `ecosystem:python-ml` | `hecks_conception/summer/**` | Stays — external ML ecosystem |
| `bootstrap:ci` | `.github/workflows/**` | Until `.hecksagon` describes CI |
| `bootstrap:git-hooks` | `bin/**`, `bin/git-hooks/**` | Until shebang bluebooks |
| `tool:audit` | `tools/**` | Until `hecks-life` dispatches audit commands |

**There are no permanent path-based exemptions** — the antibody re-fires
every time any of these files change. `EXEMPTIONS.md` is a vocabulary,
not a carve-out.

## Follow-up path

The antibody is transitional. The real win is:

1. `hecks-life run <file.bluebook>` as a stable entry point.
2. `#!/usr/bin/env hecks-life run` shebang so bluebooks are directly
   executable scripts.
3. `.hecksagon` adapters declare shell-out / git / fs / network /
   DB surfaces in the same native DSL.
4. `bin/*.bluebook` files replace every existing `bin/*` wrapper.
5. `lib/` shrinks toward zero as capabilities move into `.bluebook`
   and `.hecksagon`.
6. Eventually `hecks_life/` too — the runtime describes itself in the
   same five DSLs.

Once that's in place, the antibody stops counting exemptions and starts
counting how many non-five-DSL files are left in the repo. Zero is the
target. No Ruby, no Rust, no Python, no shell.
