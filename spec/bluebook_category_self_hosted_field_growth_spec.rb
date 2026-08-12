require "spec_helper"

# Real coverage for self-hosting `category` through the meta-grammar's own
# Bluebook aggregate: the self-hosted grammar's `Hecks.bluebook "Bluebook"`
# chapter (bluebook.bluebook) gains a `Category` value object + `attribute
# :category, Category, optional: true` on its own `Declare` command, and
# `Assembly::Contracts::CONTRACTS["Bluebook"]` gains a matching
# `category: [:category, :plain]` read -- the same three-part shape
# `redirects_native` already used to close this exact gap on Command.
#
# HONEST, VERIFIED-STILL-OPEN GAP: this makes `category` a real field the
# Judge's own Plan offers when dispatching a bluebook's Declare command
# (confirmed directly below), and a real read Assembly::Contracts knows
# about -- but the FINAL leg, `Reconstruction#to_h`'s own TOP-LEVEL chapter
# read, is hand-written rather than table-driven (its own comment: "there
# were eleven methods here... the keys come from the table now" describes
# the PER-ROW `#declaration` method further down, not this outer `#to_h`)
# and still hard-codes its chapter-level key list without `category`. So a
# real dispatch through the full Judge round-trip (meta-validation ON)
# still returns `category: nil` -- confirmed live below, not assumed.
# `Reconstruction#to_h`'s own fix is outside this migration's 31-commit
# range and not invented here.
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

  it "HONEST GAP, confirmed live: Reconstruction#to_h still does not carry category through" do
    bluebook = Hecksagain::Bluebook::IR::Bluebook.new(name: "CategorySelfHostGapGrowth", category: "framework")
    judge = Hecksagain::Bluebook::MetaValidator::Judge.new(bluebook)

    reconstructed = Hecksagain::Bluebook::MetaValidator::Reconstruction.of(judge.runtime, "CategorySelfHostGapGrowth")

    # Documented here, not silently dodged -- Reconstruction#to_h's own
    # hand-written chapter-level key list is the remaining piece, not yet
    # fixed anywhere in this migration's 31-commit range.
    expect(reconstructed).not_to have_key(:category)
  end
end
