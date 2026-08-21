module Hecksagain
  # PRD 12 (ADR 0030 Slice 3) — "the algebra we have written": the
  # EXECUTABLE shape a `Reaction` takes once every implicit choice a
  # `Policy`/`ProcessManager` leg made (context, persistence, failure
  # strategy) is a real, named value instead of which grammar keyword
  # produced it. `Runtime::ReactionLowering` (sibling concern, `runtime/
  # reaction_lowering.rb`) is what BUILDS one of these from a real
  # canonical `Bluebook::Policy`/`ProcessManager` leg; `Runtime::
  # ReactionExecutor` (`runtime/reaction_executor.rb`) is what RUNS one.
  # This module holds only the SHAPE — no behavior, no reference to
  # `Runtime` at all — the same division `Hecksagain::BluebookIR`
  # (ADR 0030's own "canonical IR", the shape every `Bluebook::` construct
  # declares) draws between a construct's declared form and the runtime
  # that interprets it: `BluebookIR` is what a `Policy`/`ProcessManager`
  # IS, declared once by a bluebook author; `PrimalIR` is what running
  # one REDUCES TO, the same handful of primitives regardless of which
  # canonical construct produced them (the provenance-erasure test's own
  # bar — `spec/reaction_executor_spec.rb` runs the identical
  # `PrimalIR::Reaction` through the identical executor whether
  # `ReactionLowering.lower_policy` or `.lower_process_manager_leg` built
  # it).
  module PrimalIR
    # `dispatches` — a list of `Dispatch`, NOT two parallel lists. REAL
    # FIX, found building the executor: a saga leg's own
    # `handler.dispatches` can fire SEVERAL commands, each with its OWN
    # `with_spec` — Settlement's own leg dispatches `Wire::Moved` (`with:
    # { wire: :reference }`) and `Drawer::Put` (`with: { number:
    # :destination, amount: :amount, reference: :reference }`), two
    # DIFFERENT binding sets. An earlier draft flattened every dispatch's
    # bindings into one shared list on `Reaction` itself — harmless for
    # the shape-only provenance test (nothing there ever resolved a
    # binding against a real dispatch), actively wrong for an executor
    # that has to know WHICH bindings belong to WHICH command. Caught
    # before the executor shipped, not after.
    Reaction = Struct.new(:trigger, :condition, :dispatches, :context, :persistence, :failure, keyword_init: true)

    # `qualifier` — the emitting AGGREGATE's own name, when `on_event`
    # was written qualified ("Account.AccountFrozen"); `nil` for a bare,
    # same-domain event name and for every process-manager leg
    # (`Behaviour::Policy#event_qualifier`, read directly).
    Trigger = Struct.new(:name, :qualifier, keyword_init: true)

    # `domain` — `nil` means "the reacting policy's own domain," the
    # same fallback `PolicyInterpreter#deliver`'s own `target` string
    # already builds (`policy.target_domain || domain`) and a process-
    # manager leg's own dispatch never needs at all (`ReactionExecutor#
    # qualify` only prefixes a domain when the command name doesn't
    # already carry one).
    CommandRef = Struct.new(:domain, :command_name, keyword_init: true)

    # ONE dispatch this `Reaction` fires — its own target and its own
    # bindings, resolved together at execution time. `bindings` is a
    # list of `Bluebook::Expression::BindingLowering::ExecutableBinding`
    # — the SAME node type for a policy's single dispatch and every one
    # of a saga leg's several, never a policy-shaped list and a saga-
    # shaped one — OR `Dispatch::VERBATIM`, below.
    Dispatch = Struct.new(:command_ref, :bindings, keyword_init: true)

    # `bindings == VERBATIM` means "ignore `bindings` entirely, hand the
    # WHOLE `sources[:payload]` to the target as-is" — `policy`'s own
    # REAL default when no `with:` is declared (`PolicyInterpreter#
    # trigger_args`'s own original comment: "the event's whole payload
    # forwards verbatim — the behaviour every policy did before `with:`
    # existed"). A genuine THIRD case, not reducible to "zero bindings":
    # an empty bindings list resolves to `{}` — no args at all — which
    # is right for a saga leg's own real default (an undeclared
    # `with_spec` sends NOTHING, no verbatim-forward concept exists
    # there at all) but silently wrong for a policy, which forwards
    # everything by default. Found by the REAL corpus failing outright
    # (every for_each/plain-trigger scenario with no declared `with:`
    # lost its whole payload) once this pass wired the executor into
    # production, not by inspection — `bindings: []` and `bindings:
    # VERBATIM` are deliberately NOT the same value for exactly this
    # reason.
    #
    # SET VIA `Dispatch::VERBATIM = ...`, NOT a bare `VERBATIM = ...`
    # inside a `Struct.new(...) do ... end` block — the first draft of
    # this used the block form, and it silently defined
    # `PrimalIR::VERBATIM`, not `Dispatch::VERBATIM`: a constant
    # assignment inside a block follows LEXICAL scope (the source text's
    # own `module`/`class` nesting), never the dynamic `self` a block
    # gets instance/class-eval'd against, regardless of method
    # definitions in the very same block correctly landing on the target
    # class. Found immediately once this was actually exercised —
    # `Dispatch::VERBATIM` raised `NameError: uninitialized constant`,
    # not silently wrong — not by inspection.
    Dispatch::VERBATIM = :verbatim

    # WHICH INSTANCE-LIFECYCLE STAGE a `Context::Correlated` reaction
    # belongs to — `Begin`/`Continue`/`End`, closed and explicit, the
    # same "no hidden mode switch" discipline every other axis here
    # already holds. Real gap, found by outside review, not by
    # inspection: `SagaInterpreter#begin_saga`/`#end_saga` never went
    # through `Reaction`/`ReactionLowering` at all — they compared
    # `event.name` against `pm.starts_on`/`pm.ends_on` directly, so the
    # "shared Reaction kernel" was silently relying on process-manager
    # PROVENANCE for behavior it claimed to represent explicitly.
    # `advance_saga`'s own leg is `Continue` — the ONLY stage that ever
    # existed as a `Reaction` before this. Each variant is a pure tag,
    # not a struct — everything ELSE a stage needs (which event
    # triggers it, what state it lands in) already lives on `Trigger`/
    # `Persistence`, the same way `Context::Stateless`/`Persistence::
    # Ephemeral`/`Failure::Drop` carry no fields of their own either.
    module Lifecycle
      Begin    = Class.new
      Continue = Class.new
      End      = Class.new
    end

    module Context
      Stateless = Class.new
      # `lifecycle` — see `Lifecycle`'s own header, immediately above.
      Correlated = Struct.new(:correlation_key, :memory, :lifecycle, keyword_init: true)
    end

    module Persistence
      Ephemeral = Class.new
      # `to_state` — the REAL missing piece a first draft of this shape
      # left out, caught building the executor: a process manager's own
      # checkpoint doesn't just record a fact, it MOVES the instance to
      # `handler.to_state` before any dispatch runs — and the
      # compensating leg's OWN guard (`unwind`'s `instance[:state] ==
      # handler.from_state`) checks against THAT already-moved state,
      # not the state the triggering leg started in. Without `to_state`
      # here, an executor has the boundary right (checkpoint before
      # dispatch) but nothing to advance the state TO, so a compensating
      # leg's own guard never matches and compensation silently never
      # fires — found by `spec/reaction_executor_spec.rb` actually
      # failing (a shut drawer's refusal never credited the source
      # drawer back), not by inspection.
      Checkpointed = Struct.new(:boundary, :to_state, keyword_init: true)
      # A `Lifecycle::End` reaction's own persistence outcome — the
      # instance's persisted record is DELETED, not moved to a new
      # state, so it genuinely doesn't fit `Checkpointed` (there is no
      # `to_state` an ended instance moves to) or `Ephemeral` (a
      # stateless policy's own "nothing to persist at all" — an ended
      # correlated instance very much had something persisted, right up
      # until this reaction). A real, previously-missing third
      # persistence strategy, found by the same outside review that
      # found `Lifecycle`'s own gap, not invented ahead of need — `End`
      # is real, exercised behavior (`SagaInterpreter#end_saga`), not
      # speculative.
      Ended = Class.new
    end

    module Failure
      Drop    = Class.new
      Managed = Struct.new(:retry, :compensation, keyword_init: true)
    end
  end
end
