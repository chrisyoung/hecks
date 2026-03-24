require "spec_helper"

RSpec.describe "Query DSL extensions" do
  let(:domain) do
    Hecks.domain "QueryExt" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :price, Integer

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
          attribute :price, Integer
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain, force: true)
    repo = @app["Pizza"]
    Hecks::Services::Querying::AdHocQueries.bind(QueryExtDomain::Pizza, repo)

    QueryExtDomain::Pizza.create(name: "Margherita", style: "Classic", price: 12)
    QueryExtDomain::Pizza.create(name: "Pepperoni", style: "Spicy", price: 15)
    QueryExtDomain::Pizza.create(name: "Hawaiian", style: "Tropical", price: 14)
    QueryExtDomain::Pizza.create(name: "Cheese", style: "Classic", price: 10)
  end

  describe "#exists?" do
    it "returns true when matching records exist" do
      expect(QueryExtDomain::Pizza.where(style: "Classic").exists?).to be true
    end

    it "returns false when no records match" do
      expect(QueryExtDomain::Pizza.where(style: "NonExistent").exists?).to be false
    end
  end

  describe "#pluck" do
    it "returns flat array for single attribute" do
      names = QueryExtDomain::Pizza.where(style: "Classic").pluck(:name)
      expect(names).to contain_exactly("Margherita", "Cheese")
    end

    it "returns array of arrays for multiple attributes" do
      results = QueryExtDomain::Pizza.where(style: "Classic").pluck(:name, :price)
      expect(results).to contain_exactly(["Margherita", 12], ["Cheese", 10])
    end

    it "returns empty array when nothing matches" do
      expect(QueryExtDomain::Pizza.where(style: "NonExistent").pluck(:name)).to eq([])
    end
  end

  describe "#sum" do
    it "sums a numeric attribute" do
      expect(QueryExtDomain::Pizza.where(style: "Classic").sum(:price)).to eq(22)
    end

    it "returns 0 for empty results" do
      expect(QueryExtDomain::Pizza.where(style: "NonExistent").sum(:price)).to eq(0)
    end
  end

  describe "#min" do
    it "returns the minimum value" do
      expect(QueryExtDomain::Pizza.where(style: "Classic").min(:price)).to eq(10)
    end

    it "returns nil for empty results" do
      expect(QueryExtDomain::Pizza.where(style: "NonExistent").min(:price)).to be_nil
    end
  end

  describe "#max" do
    it "returns the maximum value" do
      expect(QueryExtDomain::Pizza.where(style: "Classic").max(:price)).to eq(12)
    end
  end

  describe "#average" do
    it "returns the average as a float" do
      expect(QueryExtDomain::Pizza.where(style: "Classic").average(:price)).to eq(11.0)
    end

    it "returns nil for empty results" do
      expect(QueryExtDomain::Pizza.where(style: "NonExistent").average(:price)).to be_nil
    end
  end

  describe "#delete_all" do
    it "removes matching records" do
      QueryExtDomain::Pizza.where(style: "Classic").delete_all
      expect(QueryExtDomain::Pizza.where(style: "Classic").count).to eq(0)
    end

    it "does not remove non-matching records" do
      QueryExtDomain::Pizza.where(style: "Classic").delete_all
      expect(QueryExtDomain::Pizza.where(style: "Spicy").count).to eq(1)
    end
  end

  describe "#update_all" do
    it "updates matching records" do
      QueryExtDomain::Pizza.where(style: "Classic").update_all(style: "Updated")
      expect(QueryExtDomain::Pizza.where(style: "Updated").count).to eq(2)
    end

    it "does not update non-matching records" do
      QueryExtDomain::Pizza.where(style: "Classic").update_all(style: "Updated")
      expect(QueryExtDomain::Pizza.where(style: "Spicy").count).to eq(1)
    end
  end
end
