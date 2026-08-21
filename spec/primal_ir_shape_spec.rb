require "spec_helper"
require "hecksagain/primal_ir/shape"

# ADR 0030 Slice 3's own stop-condition check, the same discipline
# `binding_shape_spec.rb` already holds `BindingShape` to (Slice 2) —
# holds Ruby's hand-written `PrimalIR::Reaction`/`::Trigger`/etc.
# (lib/hecksagain/primal_ir.rb) equal, field for field, to
# `PrimalIR::Shape` (lib/hecksagain/primal_ir/shape.rb) — the SAME
# manifest `bin/project_reaction_shape` generates Rust's
# `kernel/reaction/mod.rs` from. A field added to Ruby's structs
# without a matching manifest entry fails here; a manifest entry with
# no matching Ruby field fails here too.
RSpec.describe Hecksagain::PrimalIR::Shape do
  IR = Hecksagain::PrimalIR

  it "names every Trigger field the manifest declares, and no others" do
    expect(IR::Trigger.members).to eq(described_class::NODES.fetch("Trigger").map(&:name))
  end

  it "names every CommandRef field the manifest declares, and no others" do
    expect(IR::CommandRef.members).to eq(described_class::NODES.fetch("CommandRef").map(&:name))
  end

  it "names every Dispatch field the manifest declares, and no others" do
    expect(IR::Dispatch.members).to eq(described_class::NODES.fetch("Dispatch").map(&:name))
  end

  it "names every Reaction field the manifest declares, and no others" do
    expect(IR::Reaction.members).to eq(described_class::NODES.fetch("Reaction").map(&:name))
  end

  it "declares node_names in the exact order NODES itself holds them, the same order the generated Rust structs use" do
    expect(described_class.node_names).to eq(described_class::NODES.keys)
  end

  describe "Context" do
    it "names every Correlated field the manifest declares, and no others" do
      expect(IR::Context::Correlated.members).to eq(described_class::CONTEXT_VARIANTS.fetch("Correlated").map(&:name))
    end

    it "declares Stateless as a fieldless variant, matching the manifest's own empty field list" do
      expect(described_class::CONTEXT_VARIANTS.fetch("Stateless")).to be_empty
      expect(IR::Context::Stateless.new.instance_variables).to be_empty
    end

    it "declares context_variant_names in the exact order CONTEXT_VARIANTS itself holds them" do
      expect(described_class.context_variant_names).to eq(described_class::CONTEXT_VARIANTS.keys)
    end
  end

  describe "Persistence" do
    it "names every Checkpointed field the manifest declares, and no others" do
      expect(IR::Persistence::Checkpointed.members).to eq(described_class::PERSISTENCE_VARIANTS.fetch("Checkpointed").map(&:name))
    end

    it "declares Ephemeral as a fieldless variant, matching the manifest's own empty field list" do
      expect(described_class::PERSISTENCE_VARIANTS.fetch("Ephemeral")).to be_empty
      expect(IR::Persistence::Ephemeral.new.instance_variables).to be_empty
    end

    it "declares persistence_variant_names in the exact order PERSISTENCE_VARIANTS itself holds them" do
      expect(described_class.persistence_variant_names).to eq(described_class::PERSISTENCE_VARIANTS.keys)
    end
  end

  describe "Failure" do
    it "names every Managed field the manifest declares, and no others" do
      expect(IR::Failure::Managed.members).to eq(described_class::FAILURE_VARIANTS.fetch("Managed").map(&:name))
    end

    it "declares Drop as a fieldless variant, matching the manifest's own empty field list" do
      expect(described_class::FAILURE_VARIANTS.fetch("Drop")).to be_empty
      expect(IR::Failure::Drop.new.instance_variables).to be_empty
    end

    it "declares failure_variant_names in the exact order FAILURE_VARIANTS itself holds them" do
      expect(described_class.failure_variant_names).to eq(described_class::FAILURE_VARIANTS.keys)
    end
  end

  it "regenerating rust/src/kernel/reaction/mod.rs produces no diff — the generator is deterministic and current" do
    root = InMemoryDomain::ROOT
    target = File.join(root, "rust/src/kernel/reaction/mod.rs")
    before = File.read(target)

    system(File.join(root, "bin/project_reaction_shape"), out: File::NULL, exception: true)

    expect(File.read(target)).to eq(before)
  end
end
