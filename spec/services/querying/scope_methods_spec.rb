require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Querying::ScopeMethods do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :price, Float

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
          attribute :price, Float
        end

        scope :classics, style: "Classic"
        scope :by_style, ->(s) { { style: s } }
      end
    end
  end

  before do
    @app = Hecks.load(domain)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic", price: 12.0)
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy", price: 15.0)
    PizzasDomain::Pizza.create(name: "Hawaiian", style: "Tropical", price: 14.0)
  end

  describe "hash scope" do
    it "filters by fixed conditions" do
      results = PizzasDomain::Pizza.classics
      expect(results.map(&:name)).to eq(["Margherita"])
    end

    it "returns empty when no matches" do
      PizzasDomain::Pizza.delete(PizzasDomain::Pizza.classics.first.id)
      expect(PizzasDomain::Pizza.classics.to_a).to be_empty
    end
  end

  describe "lambda scope" do
    it "accepts arguments and filters" do
      expect(PizzasDomain::Pizza.by_style("Spicy").map(&:name)).to eq(["Pepperoni"])
      expect(PizzasDomain::Pizza.by_style("Tropical").map(&:name)).to eq(["Hawaiian"])
    end

    it "returns empty for unmatched value" do
      expect(PizzasDomain::Pizza.by_style("NonExistent").to_a).to be_empty
    end
  end

  describe "scope results" do
    it "returns a QueryBuilder that supports chaining" do
      results = PizzasDomain::Pizza.classics
      expect(results).to respond_to(:order)
      expect(results).to respond_to(:limit)
      expect(results).to respond_to(:count)
    end

    it "can be counted" do
      expect(PizzasDomain::Pizza.classics.count).to eq(1)
    end

    it "can be chained with order" do
      PizzasDomain::Pizza.create(name: "Four Cheese", style: "Classic", price: 16.0)
      results = PizzasDomain::Pizza.classics.order(:name)
      expect(results.map(&:name)).to eq(["Four Cheese", "Margherita"])
    end
  end
end
