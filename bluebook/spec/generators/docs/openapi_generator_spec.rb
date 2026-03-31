require "spec_helper"

RSpec.describe Hecks::HTTP::OpenapiGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :price, Float
        attribute :points, JSON

        command "CreatePizza" do
          attribute :name, String
          attribute :price, Float
        end

        command "UpdatePizza" do
          reference_to "Pizza"
          attribute :name, String
        end

        query "ByStyle" do |style|
          where(style: style)
        end

        query "Classics" do
          where(style: "Classic")
        end
      end
    end
  end

  let(:spec) { described_class.new(domain).generate }

  describe "metadata" do
    it "uses OpenAPI 3.0" do
      expect(spec[:openapi]).to eq("3.0.0")
    end

    it "derives title from domain name" do
      expect(spec[:info][:title]).to eq("Pizzas API")
    end
  end

  describe "CRUD paths" do
    it "generates GET collection with array response" do
      get = spec[:paths]["/pizzas"][:get]
      expect(get[:summary]).to eq("List all Pizzas")
      expect(get[:responses]["200"][:content]["application/json"][:schema][:type]).to eq("array")
    end

    it "generates GET by ID with path parameter" do
      get = spec[:paths]["/pizzas/{id}"][:get]
      param = get[:parameters].first
      expect(param[:name]).to eq("id")
      expect(param[:in]).to eq("path")
      expect(param[:required]).to be true
    end

    it "generates POST with typed request body from Create command" do
      post = spec[:paths]["/pizzas"][:post]
      props = post[:requestBody][:content]["application/json"][:schema][:properties]
      expect(props[:name][:type]).to eq("string")
      expect(props[:price][:type]).to eq("number")
    end

    it "generates PATCH from Update command" do
      patch = spec[:paths]["/pizzas/{id}"][:patch]
      expect(patch).not_to be_nil
      expect(patch[:parameters].first[:name]).to eq("id")
    end

    it "generates DELETE path" do
      expect(spec[:paths]["/pizzas/{id}"][:delete]).not_to be_nil
    end
  end

  describe "query paths" do
    it "generates parameterized query with required params" do
      get = spec[:paths]["/pizzas/by_style"][:get]
      param = get[:parameters].first
      expect(param[:name]).to eq("style")
      expect(param[:in]).to eq("query")
      expect(param[:required]).to be true
    end

    it "generates parameterless query without params key" do
      get = spec[:paths]["/pizzas/classics"][:get]
      expect(get[:parameters]).to be_nil
    end
  end

  describe "component schemas" do
    it "includes all scalar attributes with correct types" do
      props = spec[:components][:schemas]["Pizza"][:properties]
      expect(props[:name][:type]).to eq("string")
      expect(props[:price][:type]).to eq("number")
      expect(props[:points][:type]).to eq("object")
      expect(props[:id][:type]).to eq("string")
      expect(props[:created_at][:format]).to eq("date-time")
    end
  end

  describe "events" do
    it "includes SSE endpoint" do
      expect(spec[:paths]["/events"]).not_to be_nil
    end
  end
end
