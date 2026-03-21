require "spec_helper"

RSpec.describe Hecks::DomainModel::Domain do
  subject(:domain) do
    described_class.new(name: "Pizzas", aggregates: [aggregate])
  end

  let(:aggregate) do
    Hecks::DomainModel::Aggregate.new(name: "Pizza", attributes: [])
  end

  describe "#module_name" do
    it "returns the domain name without spaces" do
      expect(domain.module_name).to eq("Pizzas")
    end
  end

  describe "#gem_name" do
    it "returns the underscored domain name with _domain suffix" do
      expect(domain.gem_name).to eq("pizzas_domain")
    end
  end

  describe "#aggregates" do
    it "contains the aggregates" do
      expect(domain.aggregates).to eq([aggregate])
    end
  end
end
