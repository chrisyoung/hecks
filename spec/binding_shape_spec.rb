require "spec_helper"

# PRD 10 follow-up (ADR 0030's own Slice-2 stop-condition check) — holds
# Ruby's hand-written `BindingLowering::Literal`/`::Reference`/
# `::ExecutableBinding` (binding_lowering.rb) equal, field for field, to
# `BindingShape` (binding_shape.rb) — the SAME manifest
# `bin/project_binding_shape` generates Rust's `binding/mod.rs` from. An
# operator added to Ruby's structs without a matching manifest entry
# fails here; a manifest entry with no matching Ruby field fails here —
# the same "checked equal, both directions" discipline
# `operator_conformance_spec.rb` already holds `Evaluator`'s `PROBES`
# table to, one level over.
RSpec.describe Hecksagain::Bluebook::Expression::BindingShape do
  Lowering = Hecksagain::Bluebook::Expression::BindingLowering

  it "names every Literal field the manifest declares, and no others" do
    expect(Lowering::Literal.members).to eq(described_class::NODES.fetch("Literal").map(&:name))
  end

  it "names every Reference field the manifest declares, and no others" do
    expect(Lowering::Reference.members).to eq(described_class::NODES.fetch("Reference").map(&:name))
  end

  it "names every ExecutableBinding field the manifest declares, and no others" do
    expect(Lowering::ExecutableBinding.members).to eq(described_class::EXECUTABLE_BINDING.map(&:name))
  end

  it "declares node_names in the exact order NODES itself holds them, the same order the generated Rust enum uses" do
    expect(described_class.node_names).to eq(described_class::NODES.keys)
  end

  it "regenerating rust/src/kernel/binding/mod.rs produces no diff — the generator is deterministic and current" do
    root = InMemoryDomain::ROOT
    target = File.join(root, "rust/src/kernel/binding/mod.rs")
    before = File.read(target)

    system(File.join(root, "bin/project_binding_shape"), out: File::NULL, exception: true)

    expect(File.read(target)).to eq(before)
  end
end
