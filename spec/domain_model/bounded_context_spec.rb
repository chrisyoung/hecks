require "spec_helper"

RSpec.describe Hecks::DomainModel::Structure::BoundedContext do
  let(:aggregate) do
    Hecks::DomainModel::Structure::Aggregate.new(name: "Order", attributes: [])
  end

  subject(:context) do
    described_class.new(name: "Ordering", aggregates: [aggregate])
  end

  describe "#name" do
    it "returns the context name" do
      expect(context.name).to eq("Ordering")
    end
  end

  describe "#module_name" do
    it "returns the Ruby module name" do
      expect(context.module_name).to eq("Ordering")
    end
  end

  describe "#default?" do
    it "returns false for named contexts" do
      expect(context).not_to be_default
    end

    it "returns true for Default context" do
      default = described_class.new(name: "Default")
      expect(default).to be_default
    end
  end

  describe "#aggregates" do
    it "contains the aggregates" do
      expect(context.aggregates).to eq([aggregate])
    end
  end
end
