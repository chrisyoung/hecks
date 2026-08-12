require "spec_helper"

# Real coverage for BluebookBuilder#category -- a free-form second
# classification axis (hecks_conception's own `category "framework"`,
# 119 files, 12 distinct values: framework/world/language/discipline/
# meta/body/library/plan/memory/drafting/demo/correspondence) alongside
# the fixed 3-value core/supporting/generic `classification`. A
# DIFFERENT axis, not a synonym -- both can be set on the same
# bluebook independently.
#
# `IR::Bluebook`'s own `category` field is pulled forward from a much
# later item in this same migration split (item 29, `03b5ffc`) as real
# plumbing -- without it, `BluebookBuilder#build`'s `category:
# @category` argument would have nowhere real to land.
#
# GAP CLOSED (item 39, `d39d5c1`): `BluebookBuilder#build`'s real return
# value is `MetaValidator.call(bluebook)`, which -- when meta-validation
# is ON -- dispatches the built IR through the self-hosted grammar's own
# Judge and rebuilds it via `Assembly.call(Reconstruction.of(...))`, NOT
# the original object this DSL builder constructed. `category` now
# survives that round-trip: item 35a self-hosted the field on the
# meta-grammar's own Bluebook aggregate, item 35 registered the grammar
# word, and item 39's `Reconstruction#to_h` fix (its own hand-written
# top-level chapter reader, which predates the generic contract-table
# path every OTHER category uses) was the final piece.
RSpec.describe "BluebookBuilder#category" do
  def build_bluebook(name, &block)
    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"
    Hecksagain::Bluebook::DSL::BluebookBuilder.build(name, &block)
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
  end

  it "records a free-form category string" do
    bluebook = build_bluebook("CategoryGrowth") { category "framework" }
    expect(bluebook.category).to eq("framework")
  end

  it "is independent of the fixed core/supporting/generic classification" do
    bluebook = build_bluebook("CategoryClassificationGrowth") do
      core
      category "world"
    end

    expect(bluebook.classification).to eq("core")
    expect(bluebook.category).to eq("world")
  end

  it "defaults to nil when never declared -- no behavior change for every other bluebook" do
    bluebook = build_bluebook("NoCategoryGrowth") { core }
    expect(bluebook.category).to be_nil
  end

  it "survives to_h -- the wire format a consumer with no Ruby DSL reads" do
    bluebook = build_bluebook("CategoryWireGrowth") { category "meta" }
    expect(bluebook.to_h[:category]).to eq("meta")
  end

  it "GAP CLOSED (item 39): survives the self-hosted grammar's own Judge round-trip (meta-validation ON)" do
    bluebook = Hecksagain::Bluebook::DSL::BluebookBuilder.build("CategoryReconstructionGapGrowth") do
      category "framework"
    end

    # Reconstruction#to_h (item 39) now carries `category` through its own
    # hand-written top-level chapter read -- MetaValidator's real ON-path
    # return value survives Assembly/Reconstruction intact.
    expect(bluebook.category).to eq("framework")
  end
end
