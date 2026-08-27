# `corrects`'s kernel gap, precisely scoped — it's a snapshot-format decision, not just "new kernel architecture"

**Status:** Investigated further, not implemented. ADR 0041 identified that `enforce_correction_target`'s Rust port needs "genuinely new state — either a per-instance emitted-event-name index threaded through the `Store`/dispatch pipeline... or some other mechanism not yet designed." This ADR replaces "not yet designed" with two concrete, real options, found by tracing `rust/host`'s ACTUAL production dispatch path, not just the CLI conformance harness.

## The good news, found first: the kernel already accumulates almost what's needed

`kernel::cli::run` (`rust/src/kernel/cli.rs:53`) already builds `let mut events: Vec<Event> = Vec::new();`, accumulated across every step in a run — the direct structural counterpart to Ruby's own `@registry.event_log` (`lib/hecks/runtime/registry.rb:28`, confirmed: a plain in-memory `Array`, cleared on `#clear`, not a permanent external store). If a kernel run always replayed a domain's ENTIRE command history from an empty store, checking `events` for a matching `(name, aggregate, id)` triple before dispatching a `corrects`-declaring command would be a small, real, already-available check — no new accumulator needed, just a new consumer of one that already exists.

## The real complication, found by reading `rust/host/src/dispatch.rs` directly, not assumed

`rust/host` — the actual production Lambda deployment path, not the CLI conformance harness — does NOT always replay the full history. `journal.rs`'s own header describes "the simplest correct answer" as full replay every time (ADR 0018), but `dispatch.rs`'s real `handle` function has since grown a snapshot optimization on top of that:

```rust
let snapshot = journal::load_snapshot(&txn).await?;
let mut steps = match &snapshot {
    Some(s) if !needs_saga_backfill => journal::load_steps_after(&txn, s.ordinal).await?,
    _ => journal::load_steps(&txn).await?,
};
...
let input = serde_json::json!({ "seed": seed, "steps": steps, "sagas": sagas_seed }).to_string();
```

In the common case (a snapshot exists), `steps` is only the journal rows AFTER the snapshot's own ordinal — NOT the full history. `seed` carries the snapshot's own prior record state (`Store::from_seed`) but has no analog for "which correctable events has this record already emitted." This means a `corrects` check built naively on the kernel's own per-run `events` accumulator would be **silently wrong in production**: a `CorrectFee` dispatched in an invocation AFTER the snapshot cache kicked in would never see an `ApplyFee` event that happened before the snapshot, even though the seeded record state correctly reflects it — the record would correctly show the fee applied, but `corrects "FeeApplied"` would wrongly refuse, because the events list this run's kernel sees starts empty from the snapshot forward.

## Two real options, both requiring a real decision, not a code change alone

1. **Extend the snapshot to also carry forward a per-record "corrected-event-names seen" set.** The surgical fix: alongside the record state a snapshot already carries, also persist and re-seed which correctable events (only the ones any `corrects` command in the domain actually names — not every event) this record has ever emitted. Touches `journal.rs`'s snapshot schema/persistence, `Store::from_seed`'s own seed shape, and the kernel's dispatch loop to both consult AND update this set on every relevant step. Preserves the snapshot performance optimization for domains using `corrects`.
2. **Force full replay for any domain declaring `corrects` anywhere.** Much simpler to implement — a single build-time fact ("does this domain use `corrects`") threaded into `rust/host`'s own snapshot-load decision, skipping the `journal::load_steps_after` optimization entirely for such domains, always taking the `_ => journal::load_steps(&txn).await?` branch. Correct, but a real, permanent performance tradeoff for every domain that ever adopts `corrects` — a product decision, not a unilateral engineering one, since it means a `corrects`-using domain never benefits from the snapshot cache at all, however large its journal grows.

Neither option is a small addition to what already exists — (1) is a real, load-bearing snapshot-format migration touching production persistence; (2) is a real, permanent performance-vs-simplicity tradeoff for every future domain adopting `corrects`. Both are legitimate engineering paths, and choosing between them is exactly the kind of design decision ADR 0041 already correctly flagged as needing dedicated time — this ADR makes that decision concrete and answerable instead of open-ended.

## What a future round needs, in order

1. **Decide between the two options above** — likely needs a real conversation about how heavy `corrects` usage is expected to be and how large journals typically grow, since option (2)'s cost scales with journal size while option (1)'s cost is a fixed, one-time schema/format change.
2. If (1): design the snapshot's own new field precisely (a `HashSet<(event_name, aggregate, id)>` or similar, persisted the same way the rest of `Snapshot` already is — `journal.rs`'s own schema), update `journal::load_snapshot`/whatever writes snapshots, and update the kernel's own `Store::from_seed`/dispatch loop to consult and extend it.
3. If (2): thread a per-domain "uses corrects" fact from codegen (`rust/project/domain_generator.rb` already knows this at generation time — `command[:mutations].any? { |m| m[:op] == "corrects" }`) into `rust/host`'s own snapshot-skip decision, most likely as a compiled-in constant the generated crate exposes.
4. Only then does the mechanical half ADR 0041 already scoped (allow `"corrects"` into `unsupported_ops`, a no-op mutation arm) become safe to ship alongside a REAL admissibility check — shipping the mechanical half alone, without either option above, would still mean `CorrectFee` silently accepts correcting an event that never happened, exactly the risk ADR 0041 already flagged.

## Verification

- `kernel::cli.rs`'s own `events: Vec<Event>` accumulator, and Ruby's `@registry.event_log`'s own in-memory, per-boot scoping, were both confirmed by reading the actual source, not assumed to match.
- The snapshot-optimization finding was confirmed by reading `rust/host/src/dispatch.rs`'s real `handle` function directly (`journal::load_steps_after` vs `journal::load_steps`, the `seed`/`steps` split fed to the kernel) — not inferred from `journal.rs`'s own header comment alone, which (written before the snapshot optimization existed) is now stale on this exact point ("replaying the FULL log on every invocation is the simplest correct answer" no longer describes the common-case code path, only the fallback).
- No code was changed by this investigation — this ADR converts an open, vague "needs new architecture" into two named, concrete, comparably-scoped options for a future round to choose between.
