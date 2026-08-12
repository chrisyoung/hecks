# Hecksagon

Words available inside `hecksagon do ... end`.

*The tables on this page are generated from the language's own
Syntax chapter (`lib/hecksagain/language/bluebook/syntax.bluebook`)
by `bin/reference` — do not edit inside the markers. The prose
between them is hand-written and survives regeneration.*

## subscribe

<!-- generated:begin word=subscribe -->
`subscribe subscriptions` — fills `subscriptions`

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | subscriptions |
<!-- generated:end -->

Names an event this hecksagon takes in from outside its own bluebook. It is declarative only, today — recorded on the registry (`runtime.registry.hecksagon(domain).subscriptions`) and readable back after boot, but nothing routes a subscribed event anywhere by itself. If a feature needs one to actually trigger a reaction, that reaction is still a `policy`, wired the ordinary way.

## uses_framework

<!-- generated:begin word=uses_framework -->
`uses_framework framework_members` — fills `framework_members`

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | framework_members |
<!-- generated:end -->

Names a `lib/hecksagain/framework/bluebook/` member this domain wants attached — `uses_framework "Governance"`, say. Attaching one is a deployment decision, the same kind `persisted_by`/`projected_by` already are, so it lives in the hecksagon rather than as a fact stated in the domain's own bluebook. Loads that member's own bluebook into whatever registry this one is loading into — always from its own real location, never a copy, so it keeps working even when this domain is itself copied somewhere else first (a fuzz run's isolated tmp boot, for instance). Persistence is NOT part of what this loads — a member's aggregates need their own `Hecks.hecksagon "Governance" do ... end` block, declared by whoever is attaching it, the same as any other binding decision.

## adapter

<!-- generated:begin word=adapter -->
`adapter`
<!-- generated:end -->

Two forms. Bare — `adapter :heki`/`:memory`/`:sqlite` — is a domain-wide default: every aggregate in this bluebook persists there unless it declares its own `persisted_by`, applied last so an aggregate-level bind always wins. Bare with a different kind and options — `adapter :custom_queue, url: "..."` — records a raw, opaque adapter binding, not a bind on any one aggregate. The block form — `adapter "Name" do driving on <kind> "<arg>" do |signal| dispatch "Domain::Aggregate.Command" end end` — declares a DRIVING-side construct: an external clock/file-watch/http-post reaching IN, the inverse of `persisted_by`/`charged_by`'s driven side. Structural support only; the actual scheduler that fires these is a separate concern.

## gate

<!-- generated:begin word=gate -->
`gate`
<!-- generated:end -->

`gate "Aggregate", :role do allow :Cmd1, :Cmd2, ... end` — a centralized command allowlist. Accepted so the file boots ; not stored or enforced, since each command's own `role` (see the Command context page) already checks the same thing at dispatch time, and this would be a second, easily-stale source of truth for it.

## success

<!-- generated:begin word=success -->
`success`
<!-- generated:end -->

Names the command dispatched when an adapter-mediated effect succeeds — `Aggregate.verb("Adapter", on: "Event") do success "Cmd" end`, the canonical Pizzas example's own async-verdict shape. Accepted so the file boots ; no adapter-host delivery mechanism or verdict re-entry wiring exists yet, so nothing actually calls this back.

## failure

<!-- generated:begin word=failure -->
`failure`
<!-- generated:end -->

The refusal-side sibling of `success`, naming the command dispatched when the adapter-mediated effect fails. Same structural-only status.

## port

<!-- generated:begin word=port -->
`port name do ... end` — opens a `DomainPort` body

| argument | kind | required | fills |
|---|---|---|---|
| positional 1 | text | true | name |
<!-- generated:end -->

A driving port: a second front door for a fact that didn't originate inside the domain (a payment webhook, a card terminal). Called bare, as documented here, it belongs to the chapter as a whole rather than one aggregate. The more common shape in practice is the aggregate-scoped sibling — `Pizzas::Order.port "PaymentGateway" do ... end`, the same receiver `persisted_by` already reaches (see `examples/pizzas/bluebook/pizzas.hecksagon`) — which attaches to one record's own box instead. Either way the body only admits `operation`; see the DomainPort reference page.

