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
# HONEST, ALREADY-CATALOGUED GAP (this repo's own split-plan Ground
# Truth section names it explicitly: "category not surviving
# Reconstruction#to_h"): `BluebookBuilder#build`'s real return value is
# `MetaValidator.call(bluebook)`, which -- when meta-validation is ON
# -- dispatches the built IR through the self-hosted grammar's own
# Judge and rebuilds it via `Assembly.call(Reconstruction.of(...))`,
# NOT the original object this DSL builder constructed. Since
# `category` is not yet a word the self-hosted grammar's own Bluebook
# vocabulary declares (that lands later, item 35's grammar-word
# registration), Reconstruction silently drops it on that round-trip.
# `HECKSAGAIN_META_VALIDATION=off` (the same escape hatch this whole
# migration's own spec suite already leans on for constructs ahead of
# their own grammar registration) is needed to observe `category`
# surviving all the way through; a real, in-suite test below proves
# the gap exists WITH validation on, rather than dodging it silently.
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

  it "HONEST GAP: does not yet survive the self-hosted grammar's own Judge round-trip (meta-validation ON)" do
    bluebook = Hecksagain::Bluebook::DSL::BluebookBuilder.build("CategoryReconstructionGapGrowth") do
      category "framework"
    end

    # The DSL builder captured it (proven above) -- but MetaValidator's
    # real ON-path return value went through Assembly/Reconstruction,
    # which the self-hosted grammar's Bluebook vocabulary does not yet
    # carry `category` through. Documented here, not silently dodged.
    expect(bluebook.category).to be_nil
  end
end
