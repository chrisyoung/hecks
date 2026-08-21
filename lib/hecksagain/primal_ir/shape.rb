require_relative "../primal_ir"

module Hecksagain
  module PrimalIR
    # ADR 0030 Slice 3's own stop-condition check, the same move
    # `Bluebook::Expression::BindingShape` (Slice 2) already made — see
    # that file's own header for why this is a plain manifest rather
    # than a self-hosted admission ledger like `Operator`: `PrimalIR`'s
    # own node kinds are not open-ended (growing an eighth would be a
    # new ADR-level decision, the same as `Binding`'s `Literal`/
    # `Reference`), so a ledger built for a vocabulary that never grows
    # is machinery nobody asked for.
    #
    # THIS FILE IS READ, NOT RESTATED, BY `bin/project_reaction_shape`
    # — Rust's `rust/src/kernel/reaction/mod.rs` structure is generated
    # from it. Ruby's own `PrimalIR::Reaction`/`::Trigger`/etc. (the
    # real classes, `../primal_ir.rb`) are checked equal to this
    # manifest by `spec/primal_ir_shape_spec.rb`, the same
    # "hand-written code, held to data by a spec" discipline
    # `binding_shape_spec.rb` already holds `BindingLowering` to.
    #
    # STRUCTURE ONLY, DELIBERATELY UNWIRED — matching `kernel/binding/
    # mod.rs`'s own current state (nothing in Rust calls
    # `kernel::binding` either, yet): this is the shape a Rust
    # `orchestrate.rs` executor would run, not that executor itself.
    # Converging `orchestrate.rs`'s own 981 hand-written lines onto one
    # is real, separate, larger follow-up work — see ADR 0030's own
    # 2026-08-21 update for why, and what it would still need (a real
    # way to get a LOWERED `Reaction` per domain policy/handler into
    # Rust, which this slice does not attempt).
    module Shape
      Field = Struct.new(:name, :rust_type, keyword_init: true)

      # `rust_type` — `ExecutableBinding`/`Comparison`/`Expr` reuse the
      # REAL types Slice 1 (`kernel/expr`) and Slice 2 (`kernel/
      # binding`) already generated, not fresh mirrors of the same
      # shapes — the whole payoff of doing Expression and Binding
      # first (ADR 0030's own proof-sequence ordering). `Bindings` is
      # this shape's own new enum (`Explicit(Vec<ExecutableBinding>)` /
      # `Verbatim`) — `Dispatch::VERBATIM`'s Rust counterpart, a real
      # third case, not reducible to an empty `Vec`, for the identical
      # reason the Ruby sentinel isn't (see `../primal_ir.rb`'s own
      # `Dispatch::VERBATIM` comment).
      NODES = {
        "Trigger"    => [
          Field.new(name: :name,      rust_type: "String"),
          Field.new(name: :qualifier, rust_type: "Option<String>")
        ].freeze,
        "CommandRef" => [
          Field.new(name: :domain,       rust_type: "Option<String>"),
          Field.new(name: :command_name, rust_type: "String")
        ].freeze,
        "Dispatch"   => [
          Field.new(name: :command_ref, rust_type: "CommandRef"),
          Field.new(name: :bindings,    rust_type: "Bindings")
        ].freeze,
        "Reaction"   => [
          Field.new(name: :trigger,     rust_type: "Trigger"),
          Field.new(name: :condition,   rust_type: "Option<crate::kernel::expr::Expr>"),
          Field.new(name: :dispatches,  rust_type: "Vec<Dispatch>"),
          Field.new(name: :context,     rust_type: "Context"),
          Field.new(name: :persistence, rust_type: "Persistence"),
          Field.new(name: :failure,     rust_type: "Failure")
        ].freeze
      }.freeze

      # `Context`/`Persistence`/`Failure` — each a closed, named-variant
      # enum, not an optional field a branch checks for `nil` (PRD 12's
      # own "Question 6, checked" — "no hidden mode switch," ported
      # here unchanged: the Rust shape must not reintroduce the switch
      # the Ruby shape was built specifically to avoid).
      CONTEXT_VARIANTS = {
        "Stateless"  => [].freeze,
        "Correlated" => [
          Field.new(name: :correlation_key, rust_type: "String"),
          Field.new(name: :memory,          rust_type: "bool")
        ].freeze
      }.freeze

      PERSISTENCE_VARIANTS = {
        "Ephemeral"    => [].freeze,
        # `boundary` stays `String`, not an enum with one variant today
        # — the real value is always `"before_dispatch"` (`../
        # primal_ir.rb`'s own `Persistence::Checkpointed` comment); a
        # second boundary value would be a new ADR-level decision, the
        # same reasoning `BindingShape`'s own header gives for not
        # building a ledger ahead of a vocabulary that might never grow
        # a second member.
        "Checkpointed" => [
          Field.new(name: :boundary, rust_type: "String"),
          Field.new(name: :to_state, rust_type: "String")
        ].freeze
      }.freeze

      FAILURE_VARIANTS = {
        "Drop"    => [].freeze,
        # `compensation` is `Box<Reaction>` — `Failure::Managed` can
        # recurse into another whole `Reaction` (a compensating leg is
        # a real leg, ADR 0030's own "one state machine, not a bolted-
        # on rescue path," PRD 12's own `Reaction` shape comment) — a
        # Rust enum variant holding itself by value is a compile error
        # (infinite size), so this is the one field in the whole shape
        # that needs boxing to exist at all, not a style choice.
        "Managed" => [
          Field.new(name: :retry, rust_type: "u32"),
          Field.new(name: :compensation, rust_type: "Option<Box<Reaction>>")
        ].freeze
      }.freeze

      module_function

      # The node names, in the fixed order both a generated Rust
      # `enum Bindings` (declared once here) and this file's own
      # `NODES`/`*_VARIANTS` keys must agree on — see `BindingShape.
      # node_names`'s own comment for why this is declared once rather
      # than re-derived from `.keys` at separate call sites that could
      # drift on ordering alone.
      def node_names = NODES.keys.freeze
      def context_variant_names = CONTEXT_VARIANTS.keys.freeze
      def persistence_variant_names = PERSISTENCE_VARIANTS.keys.freeze
      def failure_variant_names = FAILURE_VARIANTS.keys.freeze
    end
  end
end
