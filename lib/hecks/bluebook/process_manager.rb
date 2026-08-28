require_relative "behaviour/process_manager"
require_relative "../ir"

module Hecks
  module Bluebook
    DispatchSpec = Struct.new(:command_name, :with_spec, keyword_init: true) do
      # A Struct already answers to_h; including the mixin puts the
      # DECLARED emission ahead of Struct's own in the ancestry, which
      # is what makes the shape data rather than a method body.
      include Hecks::IR

      emits_ir(
        command_name: -> { command_name.to_s },
        with_spec:    -> { with_spec.map { |key, value| [key.to_s, Bluebook.render_value(value)] } }
      )
    end

    ProcessManagerHandler = Struct.new(:event_type, :from_state, :to_state,
                                       :dispatches, keyword_init: true) do
      include Hecks::IR

      emits_ir(
        event_type: -> { event_type.to_s },
        from_state: -> { from_state.to_s },
        to_state:   -> { to_state.to_s },
        dispatches: many(:dispatches)
      )
    end

    # The compensation half of a procedure, as its own thing.
    #
    # A PROCESS MANAGER coordinates: legs, states, an opinion about who goes
    # next. A SAGA undoes: what makes the world good again when a leg it
    # dispatched is refused. Two concepts, and the industry slurs them into one
    # word — so here they are two objects, and a procedure either has a saga or
    # does not.
    #
    # STATIC, BUILD-TIME-ONLY — NOT the runtime's own compensation path.
    # `undoes`/`reversals` exist for `model_check.rb`'s own reachability
    # check (`pm.saga?`/`pm.saga.from_state`) and nothing else; the live
    # dispatcher (`Runtime::SagaInterpreter#unwind`) never reads this
    # struct at all — it looks up `pm.handler_for(REFUSED).dispatches`
    # directly, every time. Fixing the ordering question ONLY here would
    # change nothing a real caller ever sees; it would need to move at
    # the runtime call site too.
    #
    # `undoes` is the ordered list of commands the compensation sends. Today
    # that order is the AUTHOR's, written by hand in one `on :refused` leg —
    # the runtime does not track which forward legs actually completed, so
    # compensation always replays this same fixed list, in this same fixed
    # order, however it was reached.
    #
    # CONFIRMED, NOT ASSUMED: as of this comment, that is a real but
    # CURRENTLY INERT gap, not a live bug. Every process_manager in the
    # example corpus was checked directly — only one saga (Banking's
    # `Settlement`, transfers_and_payments.bluebook) has a compensating
    # leg with more than one dispatch (two: reverse the debit, reverse
    # the transfer), and its forward legs form a strict, unbranching FSM
    # chain (`requested → awaiting_credit → awaiting_credit → settled`,
    # no `where`/guard branching) that can only ever reach `:refused`
    # from the ONE state that means "the debit already happened." So
    # declared order and actual-completion order are the same order, by
    # construction, every time, for the one real example that would
    # otherwise exercise this at all — building actual-completion-order
    # replay against that single, non-differentiating example would be
    # "a new [capability] invented speculatively for a population of
    # one" (`rust/host/src/checkout.rs`'s own header, same reasoning one
    # boundary over) — not a fix for anything currently wrong.
    # The moment a SECOND saga exists whose forward legs can complete
    # out of declared order (a guard/where branch, or two independent
    # legs with no ordering dependency between them) AND whose
    # compensation needs to know which of them actually ran, this
    # becomes real and worth building for real — not before.
    #
    # NAMING COLLISION, KNOWN AND DELIBERATE — `command`'s own `corrects
    # event, reverses: true` (docs/implemented/decisions/0036-corrects-
    # is-an-appended-fact-not-a-rewrite.md) already claims `reverses` for
    # a different meaning: auto-deriving a command's OWN corrective
    # mutation from a past EVENT, not a saga's own compensating leg from
    # a past DISPATCH. Whoever builds THIS feature should read that ADR
    # first and make a deliberate choice — reuse `reverses`'s meaning
    # here too, or pick another word — rather than colliding by accident.
    # ADR 0036 itself already carries the reciprocal cross-reference —
    # confirmed current, no drift, nothing to update there.
    Saga = Struct.new(:trigger, :from_state, :to_state, :reversals, keyword_init: true) do
      def undoes = reversals.map(&:command_name)

      def to_s = "#{trigger} → #{to_state} (#{undoes.join(', ')})"
    end

    class ProcessManager
      # The BLUEBOOK's name for this construct, asked the same way of a class
      # that has crossed over and of an IR object that has not. Collapses into
      # Construct when this one crosses.
      # The trigger of a compensating leg. Not an event name — no aggregate
      # announces that a leg the procedure dispatched was declined — so it lives
      # here beside the thing it triggers rather than in the runtime that
      # notices it. Declared in the language's Trigger vocabulary, which
      # spec/vocabulary_conformance_spec holds to this constant.
      REFUSED = Hecks::Vocabulary.fetch("Trigger").first

      include Hecks::IR
      include Behaviour::ProcessManager

      emits_ir(
        name:          :name,
        # M11 — `&.`, not `.`: a DSL-built process manager always carries
        # a real `correlates_by` (`ProcessManagerBuilder#build` refuses to
        # mint one without it), but the IR class itself defaults it to
        # `nil` and is what `Assembly::Build`'s `:identity` reader
        # (`value&.to_sym`) round-trips against. A bare `.to_s` mapped
        # that absent case to `""`, indistinguishable on the wire from a
        # real empty name and read back as the wrong, non-nil `:""`
        # instead of `nil` — the same nil-erasure S1 fixed for
        # `render_value`, one field over. `correlates_by` is always a
        # bare Symbol (`SagaInterpreter` hash-looks-up a payload by it),
        # never a `Literal`-encoded polymorphic value, so this stays a
        # local `&.` rather than routing through `Literal.render` — that
        # would wrap a real value in a leading `:` and break both the
        # `:identity` reader's plain `to_sym` and the pinned golden IR
        # fixtures' bare-string spelling (`"reference.value"`).
        correlates_by: -> { correlates_by&.to_s },
        starts_on:     :starts_on,
        ends_on:       :ends_on,
        states:        :states,
        handlers:      many(:handlers)
      )

      attr_reader :name, :correlates_by, :starts_on, :ends_on, :states, :handlers

      def initialize(name:, correlates_by: nil, starts_on: nil, ends_on: nil,
                     states: [], handlers: [])
        @name          = name.to_s
        @correlates_by = correlates_by
        @starts_on     = starts_on
        @ends_on       = ends_on
        @states        = states
        @handlers      = handlers
      end
    end
  end
end
