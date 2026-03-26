require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Querying::AdHocQueries do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain)

    repo = @app["Pizza"]
    described_class.bind(PizzasDomain::Pizza, repo)

    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
  end

  describe ".bind" do
    it "adds query methods to the class" do
      expect(PizzasDomain::Pizza).to respond_to(:where, :find_by, :order, :limit, :offset)
    end
  end

  describe ".where" do
    it "filters by conditions" do
      results = PizzasDomain::Pizza.where(style: "Classic")
      expect(results.map(&:name)).to eq(["Margherita"])
    end
  end

  describe ".find_by" do
    it "returns first match" do
      result = PizzasDomain::Pizza.find_by(name: "Pepperoni")
      expect(result.name).to eq("Pepperoni")
    end

    it "returns nil when no match" do
      expect(PizzasDomain::Pizza.find_by(name: "Nonexistent")).to be_nil
    end
  end

  describe ".order" do
    it "sorts directly on the class" do
      results = PizzasDomain::Pizza.order(:name)
      expect(results.map(&:name)).to eq(["Margherita", "Pepperoni"])
    end

    it "sorts descending" do
      results = PizzasDomain::Pizza.order(name: :desc)
      expect(results.map(&:name)).to eq(["Pepperoni", "Margherita"])
    end

    it "chains with limit" do
      results = PizzasDomain::Pizza.order(:name).limit(1)
      expect(results.map(&:name)).to eq(["Margherita"])
    end
  end

  describe ".limit" do
    it "limits directly on the class" do
      results = PizzasDomain::Pizza.limit(1)
      expect(results.to_a.size).to eq(1)
    end
  end

  describe ".offset" do
    it "offsets directly on the class" do
      results = PizzasDomain::Pizza.order(:name).offset(1)
      expect(results.map(&:name)).to eq(["Pepperoni"])
    end
  end
end
