require_relative "shared_domains"
require "spec_helper"

RSpec.describe "Type coercion: Hecks performs no runtime type checking" do
  before { @app = BreakTestDomains.boot(BreakTestDomains.simple) }

  it "accepts Integer for String attribute" do
    item = BrkSimpleDomain::Item.create(name: 42, count: 1)
    expect(item.name).to eq(42)
  end

  it "accepts String for Float attribute" do
    item = BrkSimpleDomain::Item.create(name: "x", price: "not_a_number")
    expect(item.price).to eq("not_a_number")
  end

  it "accepts Hash for JSON attribute" do
    item = BrkSimpleDomain::Item.create(name: "x", data: { key: "value" })
    expect(item.data).to be_a(Hash)
  end

  it "accepts Float::INFINITY" do
    item = BrkSimpleDomain::Item.create(name: "x", price: Float::INFINITY)
    expect(item.price).to eq(Float::INFINITY)
  end

  it "accepts Float::NAN" do
    item = BrkSimpleDomain::Item.create(name: "x", price: Float::NAN)
    expect(item.price.nan?).to be true
  end

  it "accepts negative numbers" do
    item = BrkSimpleDomain::Item.create(name: "x", count: -999, price: -1.5)
    expect(item.count).to eq(-999)
    expect(item.price).to eq(-1.5)
  end

  it "accepts very large integers" do
    big = 10**100
    item = BrkSimpleDomain::Item.create(name: "x", count: big)
    expect(item.count).to eq(big)
  end

  it "rejects unknown attributes" do
    expect { BrkSimpleDomain::Item.create(name: "x", nonexistent: "y") }.to raise_error(ArgumentError)
  end

  it "defaults missing attributes to nil" do
    item = BrkSimpleDomain::Item.create(name: "x")
    expect(item.count).to be_nil
    expect(item.price).to be_nil
    expect(item.data).to be_nil
  end

  it "accepts Symbol for String attribute" do
    item = BrkSimpleDomain::Item.create(name: :hello)
    expect(item.name).to eq(:hello)
  end

  it "accepts Array for JSON attribute" do
    item = BrkSimpleDomain::Item.create(name: "x", data: [1, 2, 3])
    expect(item.data).to eq([1, 2, 3])
  end

  it "accepts completely inverted types" do
    item = BrkSimpleDomain::Item.create(name: 999, count: "forty", price: [1, 2])
    expect(item.name).to eq(999)
    expect(item.count).to eq("forty")
    expect(item.price).to eq([1, 2])
  end

  it "update also accepts wrong types" do
    item = BrkSimpleDomain::Item.create(name: "valid", count: 1)
    updated = item.update(name: 12345, count: "string")
    expect(updated.name).to eq(12345)
  end
end
