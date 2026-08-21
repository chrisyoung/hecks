require "spec_helper"

# PRD 11 — holds Ruby's hand-written `Evaluator`/`Resolver` node structs
# equal, field for field, to `NodeShape` (node_shape.rb) — the SAME
# discipline `binding_shape_spec.rb` already applies to `BindingLowering`,
# one level up in scope: 24 real interpreter nodes instead of 2. A node
# whose real struct fields drift from what `parse` actually produces has
# nothing today to catch it; this closes exactly that gap on the Ruby
# side, ahead of and independent from PRD 11's still-open Rust-side goal
# (generating `expr.rs`'s `Expr` enum from this same manifest — not done
# here, see node_shape.rb's own header for why that's deliberately a
# separate, later step).
RSpec.describe Hecksagain::Bluebook::Expression::NodeShape do
  Evaluator = Hecksagain::Bluebook::Expression::Evaluator
  Resolver = Hecksagain::Bluebook::Expression::Resolver

  def real_class(node_name)
    owner = described_class::OWNER.fetch(node_name)
    mod = owner == :Evaluator ? Evaluator : Resolver
    mod.const_get(node_name)
  end

  # `NilLiteral` is a real, deliberate exception — resolver.rb's own
  # comment: a plain `Class.new`, not a `Struct`, because a nil literal
  # carries no data to hold. `Struct#members` does not exist on it, so
  # this is checked as "declares zero fields, and the manifest agrees,"
  # never by calling `.members` on something that has none.
  described_class::NODES.each do |name, fields|
    it "holds #{name}'s real field list equal to the manifest, both directions" do
      klass = real_class(name)
      expected = fields.map(&:name)

      if expected.empty?
        expect(klass.respond_to?(:members) ? klass.members : []).to eq([])
      else
        expect(klass.members).to eq(expected)
      end
    end
  end

  it "declares node_names in the exact order NODES itself holds them" do
    expect(described_class.node_names).to eq(described_class::NODES.keys)
  end

  it "names an owner for every declared node, and no node without one" do
    expect(described_class::OWNER.keys.sort).to eq(described_class::NODES.keys.sort)
  end

  # THE OTHER DIRECTION — a real node `Evaluator`/`Resolver` can
  # actually produce that this manifest does not know about would be
  # exactly the kind of silent drift this file exists to catch.
  # `BlockPredicate`/`Find` are the one KNOWN, DELIBERATE exception —
  # see node_shape.rb's own header (unadmitted, no settled shape) — so
  # they're the only names this check is allowed to find missing.
  it "accounts for every node kind Evaluator#parse and Resolver#parse can actually produce, except the deliberately-deferred two" do
    evaluator_nodes = Evaluator.constants.grep(/\A[A-Z]/).select { |c| Evaluator.const_get(c).is_a?(Class) && Evaluator.const_get(c) < Struct }
    resolver_nodes = Resolver.constants.grep(/\A[A-Z]/).select { |c| Resolver.const_get(c).is_a?(Class) }

    real_names = (evaluator_nodes + resolver_nodes).map(&:to_s) - %w[Operator]
    deliberately_deferred = %w[BlockPredicate Find]

    expect((real_names - deliberately_deferred).sort).to eq(described_class::NODES.keys.sort)
  end
end
