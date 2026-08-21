# PRD 11 (Rust half) — the Rust-crossing facts `NodeShape` (node_shape.rb)
# deliberately did not carry yet: which of its 26 Ruby nodes have a real
# Rust `Expr` variant at all, what that variant is actually NAMED in Rust
# (several differ from the Ruby node name — literals especially), whether
# it's a tuple/struct/unit variant (`rust/src/kernel/expr.rs`'s own
# enum mixes all three with no discoverable rule — `Include` and `Add`
# are both two-`Expr`-field nodes, one a struct variant, one a tuple; this
# is a real, historically-accumulated style choice per node, hand-
# transcribed from the file as it stands today, not inferred), and which
# individual FIELDS cross over at all (`SignTest`'s Ruby `test` field has
# no Rust counterpart — see node_shape.rb's own note on it).
#
# GROUND TRUTH FOR THIS FILE IS THE CURRENT, WORKING
# `rust/src/kernel/expr.rs` `Expr` ENUM, READ DIRECTLY, not inferred from
# `NodeShape`'s Ruby-side conceptual type names (`node_shape.rb`'s own
# "String" doesn't tell you whether Rust wants an owned `String` or a
# `&'static str` — `Lookup`'s `path` needs the latter, `StringLiteral`'s
# `value` needs the former, and nothing about the Ruby side distinguishes
# them). This file exists to encode that literal Rust truth once, so a
# generator can reproduce it exactly rather than guessing from a
# conceptual type name.
#
# `Resolve` and `ArrayLiteral` are absent from RUST_NODES on purpose —
# see `NodeShape`'s own header for why (no Rust equivalent exists for the
# first; the second has no Rust variant TODAY, structure would still be
# safe to generate but is out of this file's stated job of reproducing
# what already exists).
#
# `BlockPredicate`/`Find` ARE present — admitted in the "gaps" follow-up
# pass. Their STRUCTURE is real and generated; their INTERPRETATION
# still refuses, the exact same reason `Split`/`First`/`Last` already
# do (`expression_operators::string::split`'s own header): both need a
# real element out of the receiver, and `Value::List` still carries
# only a length. Carrying the fields structurally now (rather than
# waiting for that redesign) matches `Split`'s own precedent — its Rust
# struct keeps `separator` even though `string::split` never reads it
# before refusing.
module Hecksagain
  module Bluebook
    module Expression
      module NodeShapeRust
        # `rust_name` — the real Rust variant identifier, where it
        # differs from the Ruby node name (literals: `Int`/`Float`/`Str`/
        # `Bool`/`Nil` are not `IntegerLiteral`/`FloatLiteral`/
        # `StringLiteral`/`BoolLiteral`/`NilLiteral`; `Addition` is `Add`).
        # `kind` — `:unit` (no data), `:tuple` (positional), or `:struct`
        # (named fields) — exactly which the real enum uses today.
        # `fields` — ordered `[ruby_field_name, rust_field_name,
        # rust_type]` triples for a `:tuple`/`:struct` variant, EMPTY for
        # `:unit`. A Ruby field genuinely absent here (`SignTest`'s
        # `test`) is a deliberate omission, not an oversight — see
        # `node_shape.rb`'s own note on it.
        Node = Struct.new(:rust_name, :kind, :fields, keyword_init: true)
        RustField = Struct.new(:ruby_name, :rust_name, :rust_type, keyword_init: true)

        def self.f(ruby_name, rust_type, rust_name: nil)
          RustField.new(ruby_name: ruby_name, rust_name: rust_name || ruby_name, rust_type: rust_type)
        end

        RUST_NODES = {
          "Or"             => Node.new(rust_name: "Or", kind: :tuple,
                                       fields: [f(:left, "Box<Expr>"), f(:right, "Box<Expr>")]),
          "And"            => Node.new(rust_name: "And", kind: :tuple,
                                       fields: [f(:left, "Box<Expr>"), f(:right, "Box<Expr>")]),
          "Not"            => Node.new(rust_name: "Not", kind: :tuple, fields: [f(:node, "Box<Expr>")]),
          "Compare"        => Node.new(rust_name: "Compare", kind: :struct,
                                       fields: [f(:operator, "Comparison", rust_name: :op), f(:left, "Box<Expr>"),
                                                f(:right, "Box<Expr>")]),
          "Include"        => Node.new(rust_name: "Include", kind: :struct,
                                       fields: [f(:haystack, "Box<Expr>"), f(:needle, "Box<Expr>")]),
          "IntegerLiteral" => Node.new(rust_name: "Int", kind: :tuple, fields: [f(:value, "i64")]),
          "FloatLiteral"   => Node.new(rust_name: "Float", kind: :tuple, fields: [f(:value, "f64")]),
          "StringLiteral"  => Node.new(rust_name: "Str", kind: :tuple, fields: [f(:value, "String")]),
          "BoolLiteral"    => Node.new(rust_name: "Bool", kind: :tuple, fields: [f(:value, "bool")]),
          "NilLiteral"     => Node.new(rust_name: "Nil", kind: :unit, fields: []),
          "Addition"       => Node.new(rust_name: "Add", kind: :tuple,
                                       fields: [f(:left, "Box<Expr>"), f(:right, "Box<Expr>")]),
          # `test` deliberately excluded — see this file's own header.
          "SignTest"       => Node.new(rust_name: "SignTest", kind: :struct,
                                       fields: [f(:operator, "Comparison", rust_name: :op), f(:receiver, "Box<Expr>")]),
          "Empty"          => Node.new(rust_name: "Empty", kind: :tuple, fields: [f(:receiver, "Box<Expr>")]),
          "ToS"            => Node.new(rust_name: "ToS", kind: :tuple, fields: [f(:receiver, "Box<Expr>")]),
          "Modulo"         => Node.new(rust_name: "Modulo", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:divisor, "Box<Expr>")]),
          "Size"           => Node.new(rust_name: "Size", kind: :tuple, fields: [f(:receiver, "Box<Expr>")]),
          # `&'static str`, not `String` — generated call sites hand this
          # a compile-time-known field path, never an owned runtime
          # string. The one field whose Rust type genuinely cannot be
          # read off `NodeShape`'s own conceptual "String" label.
          "Lookup"         => Node.new(rust_name: "Lookup", kind: :tuple, fields: [f(:path, "&'static str")]),
          "MatchesRegex"   => Node.new(rust_name: "MatchesRegex", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:pattern, "String"), f(:flags, "String")]),
          "Presence"       => Node.new(rust_name: "Presence", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:negated, "bool")]),
          "Split"          => Node.new(rust_name: "Split", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:separator, "String")]),
          "First"          => Node.new(rust_name: "First", kind: :tuple, fields: [f(:receiver, "Box<Expr>")]),
          "Last"           => Node.new(rust_name: "Last", kind: :tuple, fields: [f(:receiver, "Box<Expr>")]),
          "StartsWith"     => Node.new(rust_name: "StartsWith", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:substring, "String")]),
          "EndsWith"       => Node.new(rust_name: "EndsWith", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:substring, "String")]),
          "BlockPredicate" => Node.new(rust_name: "BlockPredicate", kind: :struct,
                                       fields: [f(:mode, "String"), f(:receiver, "Box<Expr>"), f(:param, "String"),
                                                f(:predicate, "Box<Expr>")]),
          "Find"           => Node.new(rust_name: "Find", kind: :struct,
                                       fields: [f(:receiver, "Box<Expr>"), f(:param, "String"),
                                                f(:predicate, "Box<Expr>"), f(:path, "Vec<String>")])
        }.freeze

        module_function

        # The order `rust/src/kernel/expr.rs`'s own enum declares
        # variants in TODAY — preserved exactly so a generated enum is a
        # pure structural echo, not a reshuffling that produces a noisy
        # diff for no reason (the same "never alphabetized" discipline
        # `bin/project_kernel_capabilities`'s own header already states
        # for `OperatorCategory`).
        ORDER = %w[
          Or And Not Compare Include IntegerLiteral FloatLiteral StringLiteral BoolLiteral NilLiteral
          Addition SignTest Empty ToS Modulo Size Lookup
          MatchesRegex Presence Split First Last StartsWith EndsWith
          BlockPredicate Find
        ].freeze

        def rust_node_names = ORDER.freeze
      end
    end
  end
end
