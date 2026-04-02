require "spec_helper"
require "hecks/extensions/web_explorer/ir_introspector"
require "hecks/extensions/web_explorer/runtime_bridge"

RSpec.describe "Web Explorer Search and Filter" do
  let(:domain) do
    Hecks.domain "FilterTest" do
      aggregate "Product" do
        attribute :name, String
        attribute :category, String, enum: %w[electronics clothing food]
        attribute :price, Integer
        command "CreateProduct" do
          attribute :name, String
          attribute :category, String, enum: %w[electronics clothing food]
          attribute :price, Integer
        end
      end
    end
  end

  let(:mod) { Hecks.load(domain); FilterTestDomain }
  let(:bridge) { Hecks::WebExplorer::RuntimeBridge.new(mod) }
  let(:ir) { Hecks::WebExplorer::IRIntrospector.new(domain) }

  before do
    bridge.execute_command("Product", :create, { name: "Laptop", category: "electronics", price: "999" })
    bridge.execute_command("Product", :create, { name: "T-Shirt", category: "clothing", price: "29" })
    bridge.execute_command("Product", :create, { name: "Apple", category: "food", price: "2" })
  end

  describe Hecks::WebExplorer::IRIntrospector do
    it "returns filterable attributes (string and enum types)" do
      agg = ir.find_aggregate("Product")
      filterable = ir.filterable_attributes(agg)
      names = filterable.map(&:name)
      expect(names).to include(:name, :category)
      expect(names).not_to include(:price)
    end
  end

  describe Hecks::WebExplorer::RuntimeBridge do
    it "returns all records with no filters" do
      results = bridge.search_and_filter("Product", filters: {}, query: nil, filterable: [:name])
      expect(results.size).to eq(3)
    end

    it "filters by exact attribute value" do
      results = bridge.search_and_filter("Product", filters: { category: "food" }, query: nil, filterable: [:name])
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Apple")
    end

    it "searches across filterable attributes with q" do
      results = bridge.search_and_filter("Product", filters: {}, query: "lap", filterable: [:name, :category])
      expect(results.size).to eq(1)
      expect(results.first.name).to eq("Laptop")
    end

    it "combines filter and search" do
      results = bridge.search_and_filter("Product", filters: { category: "electronics" }, query: "lap", filterable: [:name])
      expect(results.size).to eq(1)
    end

    it "returns empty when filter matches nothing" do
      results = bridge.search_and_filter("Product", filters: { category: "toys" }, query: nil, filterable: [:name])
      expect(results).to be_empty
    end

    it "ignores blank filter values" do
      results = bridge.search_and_filter("Product", filters: { category: "" }, query: nil, filterable: [:name])
      expect(results.size).to eq(3)
    end
  end
end
