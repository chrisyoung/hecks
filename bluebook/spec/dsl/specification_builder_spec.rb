require "spec_helper"

RSpec.describe Hecks::DSL::SpecificationBuilder do
  it "builds a specification with a description" do
    builder = described_class.new("HighValue")
    builder.description "Orders over $1000"
    spec = builder.build

    expect(spec.name).to eq("HighValue")
    expect(spec.description).to eq("Orders over $1000")
    expect(spec.block).to be_nil
  end

  it "builds a specification with no description" do
    builder = described_class.new("Pending")
    spec = builder.build

    expect(spec.name).to eq("Pending")
    expect(spec.description).to be_nil
    expect(spec.block).to be_nil
  end
end
