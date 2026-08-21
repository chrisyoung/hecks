# PRD 11 — the one manifest describing every `Evaluator`/`Resolver` node's
# field shape, the full-grammar sibling of `BindingShape` (binding_shape.rb
# — read that file's own header first for why a plain manifest, not a
# self-hosted admission ledger, is the right-sized tool here too: this
# grammar is closed, per ADR 0022's own framing, not an open vocabulary).
#
# WHAT THIS FILE IS FOR, RIGHT NOW. Ruby's `Evaluator`/`Resolver` node
# structs are checked equal to this manifest (`spec/node_shape_spec.rb`),
# closing a real gap that existed even before any Rust question: nothing
# today holds `Evaluator::Or`/`Resolver::IntegerLiteral`/etc.'s own field
# lists equal to ANYTHING, so a struct could drift from what `parse`
# actually produces with nothing to catch it — the same class of silent
# gap PRD 09 found in the operator ledger, one level in.
#
# WHAT THIS FILE IS DELIBERATELY NOT YET FOR. Generating
# `rust/src/kernel/expr.rs`'s `Expr` enum FROM this manifest is PRD 11's
# stated goal and is not done here — replacing an already-correct,
# hand-typed, production interpreter enum wholesale is real risk to
# working code, unlike PRD 09/10 (which only ever ADDED capability where
# none existed). That step is real, scoped, and deliberately left for a
# follow-up with its own review, not rushed in alongside this lower-risk
# half. Because that follow-up isn't built yet, this manifest deliberately
# does NOT yet carry per-node Rust metadata (tuple-vs-struct variant
# style, which fields cross to Rust at all — see `SignTest`'s own note,
# below, for a real case where they don't 1:1) — inventing that shape
# now, unexercised, would be designing the harder step blind rather than
# when there's a real generator to hold it accountable.
#
# `Resolve` IS DECLARED HERE despite having NO Rust `Expr` equivalent at
# all, on purpose (`expr.rs`'s own header: "Ruby's `Resolve` is just
# interpret the wrapped Resolver node, then check truthiness... every
# `Expr` variant already produces a `Value` callers can check for
# truthiness directly"). A future Rust generator needs to know to skip
# it — recorded here in prose for now, not yet as a field, for the same
# reason given above.
#
# `ArrayLiteral` carries a real shape here despite having no Rust
# `Expr` variant today either — PRD 11's own Approach names this
# explicitly: generating the STRUCTURE is safe and cheap; Rust's
# INTERPRETATION would still refuse, the same honest-refusal precedent
# PRD 09 already set for `.split`/`.first`/`.last` (`Value::List` carries
# only a length, not elements).
#
# `BlockPredicate`/`Find` (`.all?`/`.any?`/`.none?`/`.find`) — admitted
# in the "gaps" follow-up pass, via a fifth `Strategy` value
# (`block_predicate_match`, expression.bluebook's own `Operator.Propose`
# given, extended) — PRD 09 deferred them for lack of a settled shape to
# admit against; that shape now exists, so they're declared here like
# every other real node. `predicate` is a nested `Expr` — a fully-parsed
# EVALUATOR ast, not this leaf grammar's own (`resolver/block_predicates.rb`'s
# own comment on `BlockPredicate`, read directly) — the same "Expr" label
# every other recursive field already uses, deliberately not a distinct
# type: it's the identical algebra, just entered from a different leaf.
module Hecksagain
  module Bluebook
    module Expression
      module NodeShape
        Field = Struct.new(:name, :rust_type, keyword_init: true)

        # `rust_type` values used here: "Expr" (a nested/recursive node —
        # `Box<Expr>` on the Rust side, whatever future generator reads
        # this), "String", "Integer" (Ruby) / "i64" (Rust; kept as the
        # RUBY-side type name here since this file's own job is the Ruby
        # conformance check — a future Rust generator maps Ruby type
        # names to Rust ones the same way bin/project_binding_shape's own
        # struct_def helper already does for Binding), "Float", "Boolean",
        # "Comparison" (`Evaluator::Operator`, reused unchanged — never a
        # second comparison-algebra type), "list_of(Expr)" (`ArrayLiteral`
        # only).
        NODES = {
          # ── Evaluator (outer grammar) ──────────────────────────────
          "Or"             => [Field.new(name: :left, rust_type: "Expr"), Field.new(name: :right, rust_type: "Expr")].freeze,
          "And"            => [Field.new(name: :left, rust_type: "Expr"), Field.new(name: :right, rust_type: "Expr")].freeze,
          "Not"            => [Field.new(name: :node, rust_type: "Expr")].freeze,
          "Compare"        => [Field.new(name: :operator, rust_type: "Comparison"), Field.new(name: :left, rust_type: "Expr"),
                               Field.new(name: :right, rust_type: "Expr")].freeze,
          "Include"        => [Field.new(name: :haystack, rust_type: "Expr"), Field.new(name: :needle, rust_type: "Expr")].freeze,
          # No Rust `Expr` variant — see this file's own header.
          "Resolve"        => [Field.new(name: :expr, rust_type: "Expr")].freeze,

          # ── Resolver (inner grammar / leaves) ──────────────────────
          "IntegerLiteral" => [Field.new(name: :value, rust_type: "Integer")].freeze,
          "FloatLiteral"   => [Field.new(name: :value, rust_type: "Float")].freeze,
          "StringLiteral"  => [Field.new(name: :value, rust_type: "String")].freeze,
          "BoolLiteral"    => [Field.new(name: :value, rust_type: "Boolean")].freeze,
          # No Rust `Expr` variant yet — see this file's own header.
          "ArrayLiteral"   => [Field.new(name: :elements, rust_type: "list_of(Expr)")].freeze,
          "NilLiteral"     => [].freeze,
          "Addition"       => [Field.new(name: :left, rust_type: "Expr"), Field.new(name: :right, rust_type: "Expr")].freeze,
          # `test` (the raw suffix string, e.g. "positive?") is real on
          # Ruby's own struct but carries no matching Rust field — `expr.rs`'s
          # existing hand-typed `SignTest { op, receiver }` only ever
          # needs the reduced `Comparison`, never which named suffix
          # produced it. A real Ruby/Rust field-count asymmetry, not an
          # oversight — worth a future Rust generator step's explicit
          # attention (a per-field "does this cross to Rust at all" flag),
          # not solved by this manifest as scoped today (Ruby-side check
          # only — see this file's own header).
          "SignTest"       => [Field.new(name: :operator, rust_type: "Comparison"), Field.new(name: :test, rust_type: "String"),
                               Field.new(name: :receiver, rust_type: "Expr")].freeze,
          "Empty"          => [Field.new(name: :receiver, rust_type: "Expr")].freeze,
          "ToS"            => [Field.new(name: :receiver, rust_type: "Expr")].freeze,
          "Modulo"         => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :divisor, rust_type: "Expr")].freeze,
          "Size"           => [Field.new(name: :receiver, rust_type: "Expr")].freeze,
          "Lookup"         => [Field.new(name: :path, rust_type: "String")].freeze,
          "MatchesRegex"   => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :pattern, rust_type: "String"),
                               Field.new(name: :flags, rust_type: "String")].freeze,
          "Presence"       => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :negated, rust_type: "Boolean")].freeze,
          "Split"          => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :separator, rust_type: "String")].freeze,
          "First"          => [Field.new(name: :receiver, rust_type: "Expr")].freeze,
          "Last"           => [Field.new(name: :receiver, rust_type: "Expr")].freeze,
          "StartsWith"     => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :substring, rust_type: "String")].freeze,
          "EndsWith"       => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :substring, rust_type: "String")].freeze,
          "BlockPredicate" => [Field.new(name: :mode, rust_type: "String"), Field.new(name: :receiver, rust_type: "Expr"),
                               Field.new(name: :param, rust_type: "String"), Field.new(name: :predicate, rust_type: "Expr")].freeze,
          "Find"           => [Field.new(name: :receiver, rust_type: "Expr"), Field.new(name: :param, rust_type: "String"),
                               Field.new(name: :predicate, rust_type: "Expr"), Field.new(name: :path, rust_type: "list_of(String)")].freeze
        }.freeze

        # Ruby node name -> the real class it's checked against. Declared
        # once here rather than re-derived per spec example, since
        # `Evaluator`'s five outer nodes and `Resolver`'s (plus
        # `block_predicates.rb`'s) leaves live in two different modules.
        OWNER = {
          "Or" => :Evaluator, "And" => :Evaluator, "Not" => :Evaluator, "Compare" => :Evaluator,
          "Include" => :Evaluator, "Resolve" => :Evaluator
        }.tap { |h| (NODES.keys - h.keys).each { |name| h[name] = :Resolver } }.freeze

        module_function

        def node_names = NODES.keys.freeze
      end
    end
  end
end
