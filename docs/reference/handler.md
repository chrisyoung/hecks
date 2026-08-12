# Handler

Words available inside `on do ... end`.

*The tables on this page are generated from the language's own
Syntax chapter (`lib/hecksagain/language/bluebook/syntax.bluebook`)
by `bin/reference` — do not edit inside the markers. The prose
between them is hand-written and survives regeneration.*

## dispatch

<!-- generated:begin word=dispatch -->
`dispatch command_name, with:, for_each:` — opens a `Dispatch` body

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | command_name |
| `with:` | pairs | false | with_spec |
| `for_each:` | literal | false | for_each |
<!-- generated:end -->

Fires a command from inside a handler leg, mapping the saga instance's
own fields onto the command's arguments via `with:`. Same-domain by
default like a policy's `trigger` — write `"Aggregate.Command"` — or
prefix with `"Domain::"` to reach another domain directly; there is no
separate `across` here, the qualified name carries it.

## given

<!-- generated:begin word=given -->
`given do ... end`
<!-- generated:end -->

A dispatch-level precondition on this handler's own `dispatch`es, distinct from the transition guard — the transition and any `remember`s always happen when the event fires in the right `from_state`; `given` only decides whether the dispatches actually fire. `ctx` is a merged Hash of the triggering event's payload plus the saga instance's own remembered fields.

## remember

<!-- generated:begin word=remember -->
`remember`
<!-- generated:end -->

`remember key: from_event(...)` — writes into the saga instance's own carried memory, for a LATER handler on the same instance to read back via `from_pm`. Fires once per handler firing, before this handler's own dispatches run, so a same-handler `dispatch ..., with: { y: from_pm(:key) }` composes in written order.

## set

<!-- generated:begin word=set -->
`set`
<!-- generated:end -->

`set :field, value` — the positional-argument sibling of `remember key: value`, same accumulator, same saga-memory write, just field-then-value instead of a kwarg.

## from_event

<!-- generated:begin word=from_event -->
`from_event`
<!-- generated:end -->

`from_event(field, default:)` — sugar reading a field from the triggering event's own payload, for use inside `with:`/`remember`/`set`. Returns the bare Symbol, resolved at dispatch time.

## from_iter

<!-- generated:begin word=from_iter -->
`from_iter`
<!-- generated:end -->

Same shape as `from_event`, sourcing from a `for_each` iteration row instead of the triggering event — one value per row a fanned-out dispatch enumerates.

## from_pm

<!-- generated:begin word=from_pm -->
`from_pm`
<!-- generated:end -->

Same shape again, sourcing from the process manager's own persisted state — a field an earlier handler on the same instance wrote with `remember`, rather than something the current event or iteration carries.

## template

<!-- generated:begin word=template -->
`template`
<!-- generated:end -->

`template("fmt %s", from_pm(:x, default: "y"))` — string composition inside a `with:` value, substituting resolved fields (`from_event`/`from_pm`/`from_iter`, or literals) into surrounding text via `Kernel#format`.

