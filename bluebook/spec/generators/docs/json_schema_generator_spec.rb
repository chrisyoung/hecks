require "spec_helper"
require "json"

RSpec.describe Hecks::HTTP::JsonSchemaGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :price, Float
        attribute :points, JSON
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
          attribute :price, Float
        end

        query "Classics" do
          where(style: "Classic")
        end
      end

      aggregate "Order" do
        reference_to "Pizza"
        attribute :quantity, Integer

        command "PlaceOrder" do
          reference_to "Pizza"
          attribute :quantity, Integer
        end
      end
    end
  end

  let(:schema) { described_class.new(domain).generate }
  let(:defs) { schema[:definitions] }

  describe "document structure" do
    it "is a valid JSON Schema document" do
      expect(schema["$schema"]).to include("json-schema.org")
      expect(schema[:title]).to eq("Pizzas Domain Schema")
      expect(schema[:definitions]).to be_a(Hash)
    end
  end

  describe "aggregate definitions" do
    it "includes all aggregates" do
      expect(defs).to have_key("Pizza")
      expect(defs).to have_key("Order")
    end

    it "includes all scalar attributes with correct types" do
      props = defs["Pizza"][:properties]
      expect(props[:id][:type]).to eq("string")
      expect(props[:name][:type]).to eq("string")
      expect(props[:price][:type]).to eq("number")
      expect(props[:created_at][:type]).to eq("string")
    end

    it "maps JSON attributes correctly" do
      expect(defs["Pizza"][:properties][:points][:type]).to eq(["object", "array"])
    end

    it "maps reference attributes as uuid strings" do
      ref = defs["Order"][:properties][:pizza_id]
      expect(ref[:type]).to eq("string")
      expect(ref[:format]).to eq("uuid")
      expect(ref[:description]).to include("Pizza")
    end

    it "maps list attributes as arrays with $ref items" do
      toppings = defs["Pizza"][:properties][:toppings]
      expect(toppings[:type]).to eq("array")
      expect(toppings[:items]["$ref"]).to eq("#/definitions/Pizza::Topping")
    end

    it "requires id field" do
      expect(defs["Pizza"][:required]).to include("id")
    end
  end

  describe "value object definitions" do
    it "includes value objects namespaced under aggregate" do
      expect(defs).to have_key("Pizza::Topping")
      props = defs["Pizza::Topping"][:properties]
      expect(props[:name][:type]).to eq("string")
      expect(props[:amount][:type]).to eq("integer")
    end
  end

  describe "command definitions" do
    it "includes all commands with required fields" do
      create = defs["CreatePizza"]
      expect(create[:properties][:name][:type]).to eq("string")
      expect(create[:properties][:price][:type]).to eq("number")
      expect(create[:required]).to contain_exactly("name", "price")
    end

    it "marks reference params as uuid" do
      place = defs["PlaceOrder"]
      expect(place[:properties][:pizza_id][:format]).to eq("uuid")
      expect(place[:required]).to contain_exactly("pizza_id", "quantity")
    end
  end

  describe "event definitions" do
    it "includes events with occurred_at timestamp" do
      expect(defs).to have_key("CreatedPizza")
      expect(defs["CreatedPizza"][:properties][:occurred_at][:format]).to eq("date-time")
      expect(defs["CreatedPizza"][:properties][:name][:type]).to eq("string")
    end
  end

  describe "query definitions" do
    it "includes queries with return type reference" do
      expect(defs).to have_key("Pizza.classics")
      q = defs["Pizza.classics"]
      expect(q[:returns][:type]).to eq("array")
      expect(q[:returns][:items]["$ref"]).to eq("#/definitions/Pizza")
    end

    it "includes query parameters" do
      # ByStyle not in this domain, but Classics has no params
      q = defs["Pizza.classics"]
      expect(q[:parameters]).to be_empty
    end
  end

  describe "JSON output" do
    it "produces valid JSON" do
      json = JSON.pretty_generate(schema)
      parsed = JSON.parse(json)
      expect(parsed["definitions"]).to have_key("Pizza")
    end
  end
end
