# Policy

Words available inside `policy do ... end`.

*The tables on this page are generated from the language's own
Syntax chapter (`lib/hecksagain/language/bluebook/syntax.bluebook`)
by `bin/reference` — do not edit inside the markers. The prose
between them is hand-written and survives regeneration.*

## on

<!-- generated:begin word=on -->
`on on_event` — fills `on_event`

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | on_event |
<!-- generated:end -->

The event this policy reacts to. By the time it arrives it is already a
committed fact — the policy adds no condition of its own, unlike a
command's `given`.

## trigger

<!-- generated:begin word=trigger -->
`trigger trigger_command` — fills `trigger_command`

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | trigger_command |
<!-- generated:end -->

The command `on`'s event fires, named bare — `"Aggregate.Command"`,
never domain-prefixed — because it defaults to this policy's own
domain; see `across` to reach another one. The event's whole payload
forwards verbatim as the command's arguments, so the two shapes have to
agree before either is written. A policy that ends up triggering the
event it reacts to does not loop forever: `Dispatcher::MAX_REACTION_DEPTH`
(5) stops the chain and records why.

## across

<!-- generated:begin word=across -->
`across target_domain` — fills `target_domain`

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | target_domain |
<!-- generated:end -->

Names the domain a `trigger` reaches into when it lives outside this
policy's own. Leave it off and `trigger` is assumed to name a command
in the same domain as the event that fired it — the ordinary case.

## description

<!-- generated:begin word=description -->
`description`
<!-- generated:end -->

A no-op stub — accepted so a policy using it still boots, the value discarded.

## where

<!-- generated:begin word=where -->
`where`
<!-- generated:end -->

A conditional trigger — `where field: value` — gating whether the policy fires on the triggering EVENT's own payload, equality-only against a literal hash. Distinct from an aggregate query's own `where`, which filters stored records rather than one event's fields.

## for_each

<!-- generated:begin word=for_each -->
`for_each`
<!-- generated:end -->

`for_each from: "Aggregate.query_name", where: { field: from_event(:x) }` — a policy-level fan-out, the same shape `dispatch ..., for_each:` gives a saga handler (see the Handler context page), except every `where:` value resolves against the triggering event's payload only, since a policy has no saga instance to source from.

## from_event

<!-- generated:begin word=from_event -->
`from_event`
<!-- generated:end -->

`from_event(:field)` — sugar reading a field from the triggering event's own payload, for use inside `where:`/`for_each: where:`. Returns the bare Symbol, resolved at delivery time the same way a `with:` value already is.

## with

<!-- generated:begin word=with -->
`with`
<!-- generated:end -->

`with(key, value)` — a literal extra argument attached to the triggered command's payload, beyond whatever the triggering event's own fields already supply.

## map

<!-- generated:begin word=map -->
`map`
<!-- generated:end -->

`map(**pairs)` — renames or selects an event-payload field for the triggered command's argument, folded into the same literal-argument mechanism `with` uses. Exact select-vs-merge runtime semantics are not yet verified for every shape.

## condition

<!-- generated:begin word=condition -->
`condition do ... end`
<!-- generated:end -->

A no-op stub for a comparison/boolean expression over the triggering event's own payload via a block parameter — `condition { |event| event.severity == "critical" }`. Accepted so the file boots ; a policy using it currently fires unconditionally on its `on:` event, not gated as declared, a real and documented gap distinct from the already-real `where` above (`where` is equality-only on a literal hash ; `condition` needs the full comparison grammar wired to a named block parameter, which nothing here does yet).

## cross_domain

<!-- generated:begin word=cross_domain -->
`cross_domain`
<!-- generated:end -->

`cross_domain true` — a bare boolean flag marking the policy as crossing a domain boundary conceptually, distinct from the already-real `across "DomainName"` (which names the actual target domain). Accepted and discarded ; there is no domain name here to wire it to.

