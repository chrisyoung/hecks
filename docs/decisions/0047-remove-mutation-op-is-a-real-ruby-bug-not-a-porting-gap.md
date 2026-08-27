# `remove` mutation op — investigated, found genuinely broken in Ruby itself

**Status:** Investigated, not implemented, no Rust changes made. ADR 0041 listed `remove` alongside `multiply`/`clamp` as "structurally close [to `increment`/`decrement`], but zero real corpus motivation." Attempting the same red-before/green-after discipline that shipped `multiply` (ADR 0042) and `clamp` (ADR 0046) — build a purpose-built fixture, confirm Ruby does the right thing, THEN port — found that Ruby's own `remove:` mutation, dispatched at the AGGREGATE level, does not actually remove anything from a value-object list. This is a genuine, pre-existing Ruby bug, not a Rust porting gap, and it means there is currently no correct behavior to port.

## What was tested

A purpose-built fixture (temp copy of `examples/banking`, a new `CardPayment.RemoveTag` command added: `reference_to CardPayment`, `attribute :tag, Tag`, `sets :tags, remove: :tag`) was dispatched against the REAL Ruby interpreter (`bin/rust_conformance`, Ruby-only mode):

1. `CardPayment.Authorize` with `tags: [{value: "high_risk"}, {value: "urgent"}]`.
2. `CardPayment.RemoveTag` with `tag: {value: "high_risk"}`.

**Result**: dispatch succeeded with **no refusal** and emitted `CardTagRemoved` — but the CardPayment's own final `tags` state still held **both** `high_risk` and `urgent`. The removal silently did nothing.

## Root cause, read directly

`CommandInterpreter::MutationApplier#removed` (`lib/hecks/runtime/command_interpreter/mutation_applier.rb:157`):

```ruby
def removed(instance, aggregate, mutation, args)
  value     = @rules.resolve_source(mutation.source, args)
  attribute = aggregate.attribute(mutation.target)
  value     = Value.for_attribute(aggregate, attribute, value) if attribute
  Array(instance[mutation.target]).reject { |element| element == value }
end
```

`attribute` here is the LIST attribute itself (`tags`, declared `list_of(Tag)`) — not the element type. `Value.for_attribute(aggregate, attribute, value)` (`lib/hecks/runtime/value/coercion.rb:52`) checks `attribute.list?` FIRST (true, since `tags` is a list) and routes through `hydrate_entity_list(aggregate, attribute, value)` (`coercion.rb:306`) — a function whose whole job is "hydrate an ARRAY of raw hashes into an array of typed elements," not "coerce one scalar value into the element type." Two different failure modes depending on what the list holds:

- **A value-object list** (this fixture's `tags: list_of(Tag)`): `find_entity(aggregate, "Tag")` finds no entity named `Tag` (it's a value object, not an entity) — `hydrate_entity_list` immediately `return value unless entity`, handing back the ORIGINAL RAW HASH `{value: "high_risk"}`, completely uncoerced. Back in `removed`, `element == value` compares a real `Value` instance (each stored `Tag`) against a raw `Hash` — `Value#==` (`lib/hecks/runtime/value.rb:46`) requires `other.is_a?(self.class)`, which a Hash never is, so this comparison is **always false**. `reject` removes nothing, silently, for a value-object list target — confirmed exactly by this fixture.
- **An entity list** (e.g. `Account.ledger: list_of(LedgerEntry)`, traced but not fixture-tested): `find_entity` DOES find the entity, so `hydrate_entity_list` proceeds — but its own contract is "wrap in `Array(value)`, hydrate EVERY element inside," meaning a single scalar identity value meant to MATCH one existing element gets wrapped into a ONE-ELEMENT ARRAY containing a hydrated hash, not a bare matchable value. `removed`'s own `element == value` then compares each real list element against that wrapping ARRAY — never equal either, for a structurally different reason than the value-object case, but the same practical outcome: nothing is ever removed.

Either way, **the fundamental problem is the same**: `Value.for_attribute` was written to coerce a value into ONE attribute's own declared type, and `remove:`'s call site hands it the LIST attribute itself rather than the list's ELEMENT type — a category error the function has no way to detect or recover from.

## Why this is not this session's own bug to fix, and not a Rust porting gap

This is pre-existing Ruby runtime code (`command_builder.rb`'s own comment dates it "migration plan task 4," a "vendored addition, not (yet) upstream hecks"), not something introduced by Phase 10's own work this session. It has evidently never been exercised end-to-end before: no domain in `examples/` declares `remove:` at all (confirmed by grep, same as ADR 0041's own finding), and the citation `command_builder.rb` itself makes (`plan.bluebook`'s own `RemoveDependency`/`DeactivateSprint`) lives in a domain outside this repo entirely — meaning this bug has likely been silently present, and silently never caught, since it was vendored in.

This also means there is **no correct Ruby behavior for a Rust port to target** right now. ADR 0010 ("Ruby is the reference implementation") means Rust conforms to what Ruby actually does — but "silently do nothing while reporting success" is not a behavior worth reproducing, and building a Rust `remove:` that ACTUALLY removes the matching element (the obviously-intended behavior, read directly from every comment describing this feature) would make Rust diverge from Ruby's own real, broken behavior — the opposite of closing the equivalence gap.

## What a future round needs, in order

1. **Fix `Value.for_attribute`'s call site in `removed`, in Ruby, first** — the fix belongs in `mutation_applier.rb`, not `coercion.rb` itself (`for_attribute`'s own `attribute.list?` branch is correct for every OTHER caller; `removed` is the one caller passing it the wrong kind of attribute for what it's trying to do). The right fix is almost certainly reading the list's own ELEMENT type (the same way `command_rules/arithmetic.rb`'s VO-field matching, or `append`'s own element resolution, already does) and coercing `value` against THAT type instead of the list attribute itself.
2. **Re-verify against this exact fixture** (or a permanent one, if this graduates to real corpus content) that a value-object list's `remove:` actually removes the matching element once fixed.
3. **Only then** does porting `remove:` to Rust become a well-scoped, ADR-0042/0046-shaped round: a real, correct Ruby behavior to target, verified red-before/green-after the usual way.

## Verification

- The broken-removal finding was confirmed by direct dispatch against Ruby's real interpreter (`bin/rust_conformance`, Ruby-only mode) — not inferred from reading code alone: `refusals: []`, `CardTagRemoved` emitted, final `tags` state unchanged (`high_risk` still present alongside `urgent`).
- The entity-list failure mode was traced through `hydrate_entity_list`'s own code directly but NOT independently fixture-tested (the value-object-list case alone was sufficient to establish "remove: is currently broken," and building a second fixture to also prove the entity-list case broken adds confirmation but not a different conclusion) — noted here as unconfirmed-by-fixture so a future round doesn't mistake this ADR's tracing for the same rigor as the value-object case's direct proof.
- No production code was changed by this investigation. `bundle exec rspec`/`rubocop` were already green going in and remain untouched — this ADR is pure investigation output.
