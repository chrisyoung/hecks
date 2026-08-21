require "spec_helper"

# PRD 11 (Rust half) — checks NodeShapeRust's own internal consistency
# against NodeShape (its Ruby-side sibling, already checked against the
# real Evaluator/Resolver structs by spec/node_shape_spec.rb): every
# Rust-crossing node must be a real declared node, every Rust field must
# trace back to a real Ruby field on that node, and ORDER must be exactly
# the set RUST_NODES declares — no silent drift between the two files.
RSpec.describe Hecksagain::Bluebook::Expression::NodeShapeRust do
  NodeShape = Hecksagain::Bluebook::Expression::NodeShape

  it "names only real nodes NodeShape itself declares" do
    expect(described_class::RUST_NODES.keys - NodeShape::NODES.keys).to be_empty
  end

  it "excludes exactly Resolve and ArrayLiteral, and nothing else, from the Rust-crossing set" do
    excluded = NodeShape::NODES.keys - described_class::RUST_NODES.keys
    expect(excluded.sort).to eq(%w[ArrayLiteral Resolve])
  end

  it "ORDER is exactly RUST_NODES's own key set, no more, no fewer" do
    expect(described_class.rust_node_names.sort).to eq(described_class::RUST_NODES.keys.sort)
  end

  it "gives every :unit node zero fields, and every :tuple/:struct node at least one" do
    described_class::RUST_NODES.each_value do |node|
      if node.kind == :unit
        expect(node.fields).to be_empty
      else
        expect(node.fields).not_to be_empty
      end
    end
  end

  described_class::RUST_NODES.each do |name, node|
    it "traces every #{name} Rust field back to a real Ruby field NodeShape declares" do
      real_ruby_fields = NodeShape::NODES.fetch(name).map(&:name)
      expect(node.fields.map(&:ruby_name) - real_ruby_fields).to be_empty
    end
  end

  it "flags SignTest's own field-count asymmetry explicitly, rather than silently dropping a field" do
    ruby_fields = NodeShape::NODES.fetch("SignTest").map(&:name)
    rust_fields = described_class::RUST_NODES.fetch("SignTest").fields.map(&:ruby_name)

    expect(ruby_fields - rust_fields).to eq([:test])
  end

  it "regenerating rust/src/kernel/expr/mod.rs produces no diff — the generator is deterministic and current" do
    root = InMemoryDomain::ROOT
    target = File.join(root, "rust/src/kernel/expr/mod.rs")
    before = File.read(target)

    system(File.join(root, "bin/project_expr_shape"), out: File::NULL, exception: true)

    expect(File.read(target)).to eq(before)
  end
end
