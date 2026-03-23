require_relative "shared_domains"
require "spec_helper"

RSpec.describe "QueryBuilder destructive tests" do
  before do
    @app = BreakTestDomains.boot(BreakTestDomains.multi_field)
    repo = @app["Item"]
    Hecks::Services::Querying::AdHocQueries.bind(BrkMultiDomain::Item, repo)

    BrkMultiDomain::Item.create(name: "Alpha",   category: "A", color: "red",   size: "S", weight: 1)
    BrkMultiDomain::Item.create(name: "Bravo",   category: "A", color: "blue",  size: "M", weight: 2)
    BrkMultiDomain::Item.create(name: "Charlie", category: "B", color: "red",   size: "L", weight: 3)
    BrkMultiDomain::Item.create(name: "Delta",   category: "B", color: "green", size: "S", weight: 4)
    BrkMultiDomain::Item.create(name: "Echo",    category: "C", color: "blue",  size: "M", weight: 5)
  end

  it "where({}) returns all" do
    expect(BrkMultiDomain::Item.where(**{}).to_a.size).to eq(5)
  end

  it "order by nonexistent attribute doesn't crash" do
    expect { BrkMultiDomain::Item.order(:nonexistent).to_a }.not_to raise_error
  end

  it "limit(0) returns empty" do
    expect(BrkMultiDomain::Item.limit(0).to_a).to eq([])
  end

  it "limit(-1) returns empty (clamped to 0)" do
    expect { BrkMultiDomain::Item.limit(-1).to_a }.not_to raise_error
    expect(BrkMultiDomain::Item.limit(-1).to_a).to eq([])
  end

  it "offset > count returns empty" do
    expect(BrkMultiDomain::Item.offset(100).to_a).to eq([])
  end

  it "offset(-1) returns all (clamped to 0)" do
    expect(BrkMultiDomain::Item.offset(-1).to_a.size).to eq(5)
  end

  it "5x chained where narrows correctly" do
    results = BrkMultiDomain::Item.where(category: "A").where(color: "red").where(size: "S").where(weight: 1).where(name: "Alpha")
    expect(results.to_a.size).to eq(1)
  end

  it "find_by with multiple conditions" do
    expect(BrkMultiDomain::Item.find_by(category: "B", color: "green").name).to eq("Delta")
    expect(BrkMultiDomain::Item.find_by(category: "A", color: "green")).to be_nil
  end

  it "to_a is idempotent" do
    query = BrkMultiDomain::Item.where(category: "A").order(:name)
    expect(query.to_a.map(&:name)).to eq(query.to_a.map(&:name))
  end

  it "count after limit respects limit" do
    expect(BrkMultiDomain::Item.where(category: "A").limit(1).count).to eq(1)
  end

  it "limit(nil) and offset(nil) are no-ops" do
    expect(BrkMultiDomain::Item.limit(nil).to_a.size).to eq(5)
    expect(BrkMultiDomain::Item.offset(nil).to_a.size).to eq(5)
  end
end
