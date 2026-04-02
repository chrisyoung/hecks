require "spec_helper"

RSpec.describe Hecks::Querying::FinderMethods do
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

        finder :by_style, :style
        finder :by_name_and_style, :name, :style
      end
    end
  end

  before do
    @app = Hecks.load(domain)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic", price: 12.0)
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy", price: 15.0)
    PizzasDomain::Pizza.create(name: "Hawaiian", style: "Classic", price: 14.0)
  end

  describe "DSL definition" do
    it "stores finders on the aggregate IR" do
      agg = domain.aggregates.first
      expect(agg.finders.size).to eq(2)
      expect(agg.finders.map(&:name)).to eq([:by_style, :by_name_and_style])
    end

    it "records param names" do
      agg = domain.aggregates.first
      finder = agg.finders.find { |f| f.name == :by_name_and_style }
      expect(finder.params).to eq([:name, :style])
    end
  end

  describe "single-param finder" do
    it "defines a class method on the aggregate" do
      expect(PizzasDomain::Pizza).to respond_to(:by_style)
    end

    it "returns matching records" do
      results = PizzasDomain::Pizza.by_style("Classic")
      expect(results.map(&:name).sort).to eq(["Hawaiian", "Margherita"])
    end

    it "returns empty array when no matches" do
      expect(PizzasDomain::Pizza.by_style("NonExistent")).to be_empty
    end
  end

  describe "multi-param finder" do
    it "filters by all params" do
      results = PizzasDomain::Pizza.by_name_and_style("Margherita", "Classic")
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Margherita")
    end

    it "returns empty when one param mismatches" do
      expect(PizzasDomain::Pizza.by_name_and_style("Margherita", "Spicy")).to be_empty
    end
  end

  describe "DSL serialization" do
    it "includes finders in serialized output" do
      output = Hecks::DslSerializer.new(domain).serialize
      expect(output).to include("finder :by_style, :style")
      expect(output).to include("finder :by_name_and_style, :name, :style")
    end
  end

  describe "aggregate rebuilder" do
    it "preserves finders through rebuild" do
      agg = domain.aggregates.first
      builder = Hecks::DSL::AggregateRebuilder.from_aggregate(agg)
      rebuilt = builder.build
      expect(rebuilt.finders.size).to eq(2)
      expect(rebuilt.finders.first.name).to eq(:by_style)
      expect(rebuilt.finders.first.params).to eq([:style])
    end
  end
end
