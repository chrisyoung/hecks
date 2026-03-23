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
    end
  end

  let(:schema) { described_class.new(domain).generate }

  it "generates a single schema document" do
    expect(schema[:title]).to eq("Pizzas Domain Schema")
    expect(schema["$schema"]).to include("json-schema.org")
  end

  it "includes aggregate definitions" do
    expect(schema[:definitions]).to have_key("Pizza")
    expect(schema[:definitions]["Pizza"][:properties][:name][:type]).to eq("string")
    expect(schema[:definitions]["Pizza"][:properties][:price][:type]).to eq("number")
  end

  it "includes JSON type attributes" do
    expect(schema[:definitions]["Pizza"][:properties][:points][:type]).to eq(["object", "array"])
  end

  it "includes list attributes with $ref to value object" do
    toppings = schema[:definitions]["Pizza"][:properties][:toppings]
    expect(toppings[:type]).to eq("array")
    expect(toppings[:items]["$ref"]).to include("Topping")
  end

  it "includes value object definitions" do
    expect(schema[:definitions]).to have_key("Pizza::Topping")
  end

  it "includes command definitions with required fields" do
    expect(schema[:definitions]).to have_key("CreatePizza")
    expect(schema[:definitions]["CreatePizza"][:required]).to include("name", "price")
  end

  it "includes event definitions" do
    expect(schema[:definitions]).to have_key("CreatedPizza")
    expect(schema[:definitions]["CreatedPizza"][:properties][:occurred_at]).not_to be_nil
  end

  it "includes query definitions" do
    expect(schema[:definitions]).to have_key("Pizza.classics")
  end
end
