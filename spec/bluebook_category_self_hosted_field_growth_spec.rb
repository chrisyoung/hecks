require "spec_helper"

# Real coverage for self-hosting `category` through the meta-grammar's own
# Bluebook aggregate: the self-hosted grammar's `Hecks.bluebook "Bluebook"`
# chapter (bluebook.bluebook) gains a `Category` value object + `attribute
# :category, Category, optional: true` on its own `Declare` command, and
# `Assembly::Contracts::CONTRACTS["Bluebook"]` gains a matching
# `category: [:category, :plain]` read -- the same three-part shape
# `redirects_native` already used to close this exact gap on Command.
#
# GAP CLOSED (item 39, `d39d5c1`): this makes `category` a real field the
# Judge's own Plan offers when dispatching a bluebook's Declare command
# (confirmed directly below), a real read Assembly::Contracts knows about,
# AND now the FINAL leg too -- `Reconstruction#to_h`'s own TOP-LEVEL
# chapter read (hand-written rather than table-driven, unlike every OTHER
# category's `#declaration` method) gained its own `category:` line, so a
# real dispatch through the full Judge round-trip (meta-validation ON)
# now returns the real value -- confirmed live below, not assumed.
RSpec.describe "the self-hosted grammar's own Bluebook.category field" do
  it "the self-hosted Bluebook aggregate's Declare command now offers category" do
    plan = Hecksagain::Bluebook::MetaValidator::Plan.for(Hecksagain::Bluebook::MetaValidator.grammar_registry)
    bluebook_category = plan.category("Bluebook")

    expect(bluebook_category.fields).to include("category")
  end

  it "Assembly::Contracts reads Bluebook's category field back as a plain value" do
    contract = Hecksagain::Bluebook::Assembly.contract("Bluebook")
    expect(contract.fields[:category]).to eq([:category, :plain])
  end

  it "a real dispatch through the Judge raises no refusal for a declared category" do
    bluebook = Hecksagain::Bluebook::IR::Bluebook.new(name: "CategorySelfHostGrowth", category: "framework")
    judge = Hecksagain::Bluebook::MetaValidator::Judge.new(bluebook)

    expect(judge.refusals).to be_empty
  end

  it "GAP CLOSED (item 39): Reconstruction#to_h now carries category through" do
    bluebook = Hecksagain::Bluebook::IR::Bluebook.new(name: "CategorySelfHostGapGrowth", category: "framework")
    judge = Hecksagain::Bluebook::MetaValidator::Judge.new(bluebook)

    reconstructed = Hecksagain::Bluebook::MetaValidator::Reconstruction.of(judge.runtime, "CategorySelfHostGapGrowth")

    # Reconstruction#to_h's own hand-written chapter-level key list gained
    # a `category:` line (item 39) -- the round trip is complete now.
    expect(reconstructed[:category]).to eq("framework")
  end
end
