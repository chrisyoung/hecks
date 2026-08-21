# PRD 10 follow-up (ADR 0030's own Slice-2 stop-condition check) — the
# ONE structural definition `bin/project_binding_shape` generates
# Rust's `rust/src/kernel/binding/mod.rs` from, closing the "two
# hand-authored mirrors" gap PRD 10 shipped with and flagged honestly.
#
# WHY A PLAIN MANIFEST, NOT A SELF-HOSTED BLUEBOOK LEDGER LIKE
# `Operator`. `expression.bluebook`'s `Operator`/`Normalisation`
# aggregates earn a real admission lifecycle (propose → render → admit)
# because the operator VOCABULARY is genuinely open-ended — it grows one
# real-world gap at a time (PRD 09's own eight). `Binding`'s executable
# shape is not open-ended the same way: `Literal`/`Reference` are the
# whole algebra ADR 0030 designed for it, and growing a THIRD node kind
# would be a new ADR-level decision, not a routine admission. A ledger
# built for a vocabulary that doesn't grow is machinery nobody asked
# for — this file is the plainest thing that lets ONE definition drive
# TWO generated representations, which is the actual, narrower claim
# this closes.
#
# THIS FILE IS READ, NOT RESTATED, BY BOTH SIDES. Ruby's own
# `BindingLowering::Literal`/`::Reference`/`::ExecutableBinding`
# (binding_lowering.rb) are checked equal to this manifest by
# `spec/binding_shape_spec.rb` — the same "hand-written code, held to
# data by a spec" shape `operator_conformance_spec.rb` already uses for
# `Evaluator`'s PROBES table, rather than generating Ruby FROM this
# manifest too (Ruby's own Struct-based definitions are already the
# simplest possible spelling of this shape; regenerating them would add
# a build step for no reduction in duplication risk). Rust's
# `binding/mod.rs` IS generated from this, because Rust is where the
# real risk of drift actually lives — no human reads Rust before it
# fails to compile.
module Hecksagain
  module Bluebook
    module Expression
      module BindingShape
        Field = Struct.new(:name, :rust_type, keyword_init: true)

        # `rust_type` is the exact Rust type each field carries in
        # `rust/src/kernel/binding/mod.rs` — `Value` is `crate::kernel::
        # expr::Value` (PRD 10's own reuse of the Expression algebra's
        # value type, not a second one), `Vec<String>` is the ordered
        # source-bucket priority list.
        NODES = {
          "Literal"   => [
            Field.new(name: :value, rust_type: "Value")
          ].freeze,
          "Reference" => [
            Field.new(name: :name, rust_type: "String"),
            Field.new(name: :priority, rust_type: "Vec<String>")
          ].freeze
        }.freeze

        EXECUTABLE_BINDING = [
          Field.new(name: :destination, rust_type: "String"),
          Field.new(name: :source, rust_type: "Source")
        ].freeze

        module_function

        # The node names, in the fixed order both a generated Rust
        # `enum Source` and this file's own `NODES` keys must agree on —
        # declared once here rather than re-derived from `NODES.keys`
        # at two different call sites that could drift on ordering alone.
        def node_names = NODES.keys.freeze
      end
    end
  end
end
