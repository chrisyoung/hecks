require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Querying::Operators do
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
      end
    end
  end

  before do
    @app = Hecks.load(domain)

    repo = @app["Pizza"]
    Hecks::Querying::AdHocQueries.bind(PizzasDomain::Pizza, repo)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic", price: 12.0)
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy", price: 15.0)
    PizzasDomain::Pizza.create(name: "Hawaiian", style: "Tropical", price: 14.0)
    PizzasDomain::Pizza.create(name: "Cheese", style: "Classic", price: 10.0)
  end

  describe "Gt" do
    it "matches values strictly greater than" do
      results = PizzasDomain::Pizza.where(price: described_class::Gt.new(13.0))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end

    it "excludes the exact boundary value" do
      results = PizzasDomain::Pizza.where(price: described_class::Gt.new(14.0))
      expect(results.map(&:name)).to eq(["Pepperoni"])
    end

    it "returns empty when nothing matches" do
      results = PizzasDomain::Pizza.where(price: described_class::Gt.new(100.0))
      expect(results.to_a).to be_empty
    end
  end

  describe "Gte" do
    it "includes the boundary value" do
      results = PizzasDomain::Pizza.where(price: described_class::Gte.new(14.0))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end
  end

  describe "Lt" do
    it "matches values strictly less than" do
      results = PizzasDomain::Pizza.where(price: described_class::Lt.new(12.0))
      expect(results.map(&:name)).to eq(["Cheese"])
    end

    it "excludes the exact boundary value" do
      results = PizzasDomain::Pizza.where(price: described_class::Lt.new(10.0))
      expect(results.to_a).to be_empty
    end
  end

  describe "Lte" do
    it "includes the boundary value" do
      results = PizzasDomain::Pizza.where(price: described_class::Lte.new(10.0))
      expect(results.map(&:name)).to eq(["Cheese"])
    end
  end

  describe "NotEq" do
    it "excludes matching values" do
      results = PizzasDomain::Pizza.where(style: described_class::NotEq.new("Classic"))
      expect(results.map(&:name)).to contain_exactly("Pepperoni", "Hawaiian")
    end

    it "returns all when excluding nonexistent value" do
      results = PizzasDomain::Pizza.where(style: described_class::NotEq.new("NonExistent"))
      expect(results.count).to eq(4)
    end
  end

  describe "In" do
    it "matches any value in the set" do
      results = PizzasDomain::Pizza.where(style: described_class::In.new(["Classic", "Tropical"]))
      expect(results.map(&:name)).to contain_exactly("Margherita", "Hawaiian", "Cheese")
    end

    it "returns empty for empty set" do
      results = PizzasDomain::Pizza.where(style: described_class::In.new([]))
      expect(results.to_a).to be_empty
    end

    it "works with single-element set" do
      results = PizzasDomain::Pizza.where(style: described_class::In.new(["Spicy"]))
      expect(results.map(&:name)).to eq(["Pepperoni"])
    end
  end

  describe "operator combinations" do
    it "combines operator on one field with equality on another (AND)" do
      builder = Hecks::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(style: "Classic").where(price: builder.gt(11.0))
      expect(results.map(&:name)).to eq(["Margherita"])
    end

    it "combines not_eq with gt" do
      builder = Hecks::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(style: builder.not_eq("Classic")).where(price: builder.gt(14.5))
      expect(results.map(&:name)).to eq(["Pepperoni"])
    end

    it "combines operator with equality" do
      builder = Hecks::Querying::QueryBuilder.new(@app["Pizza"])
      results = builder.where(style: "Classic").where(price: builder.gt(11.0))
      expect(results.map(&:name)).to eq(["Margherita"])
    end
  end

  describe "match? protocol" do
    it "Gt.match? returns correct boolean" do
      op = described_class::Gt.new(10)
      expect(op.match?(15)).to be true
      expect(op.match?(10)).to be false
      expect(op.match?(5)).to be false
      expect(op.match?(nil)).to be false
    end

    it "NotEq.match? handles nil" do
      op = described_class::NotEq.new("x")
      expect(op.match?(nil)).to be true
      expect(op.match?("x")).to be false
    end

    it "In.match? checks inclusion" do
      op = described_class::In.new([1, 2, 3])
      expect(op.match?(2)).to be true
      expect(op.match?(4)).to be false
    end
  end
end
