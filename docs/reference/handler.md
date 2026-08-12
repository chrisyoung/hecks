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

<!-- TODO: document this word -->

## remember

<!-- generated:begin word=remember -->
`remember`
<!-- generated:end -->

<!-- TODO: document this word -->

## set

<!-- generated:begin word=set -->
`set`
<!-- generated:end -->

<!-- TODO: document this word -->

## from_event

<!-- generated:begin word=from_event -->
`from_event`
<!-- generated:end -->

<!-- TODO: document this word -->

## from_iter

<!-- generated:begin word=from_iter -->
`from_iter`
<!-- generated:end -->

<!-- TODO: document this word -->

## from_pm

<!-- generated:begin word=from_pm -->
`from_pm`
<!-- generated:end -->

<!-- TODO: document this word -->

## template

<!-- generated:begin word=template -->
`template`
<!-- generated:end -->

<!-- TODO: document this word -->

