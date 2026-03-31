require "spec_helper"

RSpec.describe Hecks::HTTP::RpcDiscovery do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :price, Float

        command "CreatePizza" do
          attribute :name, String
          attribute :price, Float
        end

        query "ByStyle" do |style|
          where(style: style)
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

  let(:discovery) { described_class.new(domain).generate }
  let(:methods) { discovery[:methods] }

  describe "metadata" do
    it "includes domain name" do
      expect(discovery[:name]).to eq("Pizzas RPC")
    end
  end

  describe "command methods" do
    it "includes every command with correct parameter types" do
      create = methods.find { |m| m[:name] == "CreatePizza" }
      expect(create[:params].size).to eq(2)
      expect(create[:params].map { |p| p[:name] }).to eq(["name", "price"])
      expect(create[:params].map { |p| p[:type] }).to eq(["String", "Float"])
    end

    it "marks reference params as String type" do
      place = methods.find { |m| m[:name] == "PlaceOrder" }
      pizza_param = place[:params].find { |p| p[:name] == "pizza_id" }
      expect(pizza_param[:type]).to eq("String")
    end
  end

  describe "query methods" do
    it "includes parameterized queries with params" do
      by_style = methods.find { |m| m[:name] == "Pizza.by_style" }
      expect(by_style[:params].size).to eq(1)
      expect(by_style[:params].first[:name]).to eq("style")
    end

    it "includes parameterless queries with empty params" do
      classics = methods.find { |m| m[:name] == "Pizza.classics" }
      expect(classics[:params]).to be_empty
    end
  end

  describe "CRUD methods" do
    it "includes find, all, count, delete for each aggregate" do
      names = methods.map { |m| m[:name] }
      %w[Pizza.find Pizza.all Pizza.count Pizza.delete
         Order.find Order.all Order.count Order.delete].each do |method|
        expect(names).to include(method)
      end
    end

    it "find has id parameter" do
      find = methods.find { |m| m[:name] == "Pizza.find" }
      expect(find[:params].first[:name]).to eq("id")
    end

    it "all and count have no parameters" do
      expect(methods.find { |m| m[:name] == "Pizza.all" }[:params]).to be_empty
      expect(methods.find { |m| m[:name] == "Pizza.count" }[:params]).to be_empty
    end

    it "delete has id parameter" do
      del = methods.find { |m| m[:name] == "Pizza.delete" }
      expect(del[:params].first[:name]).to eq("id")
    end
  end

  describe "completeness" do
    it "generates methods for all aggregates" do
      aggregate_names = methods.map { |m| m[:name].split(".").first }.uniq
      # Commands don't have dot notation, but CRUD and queries do
      expect(aggregate_names).to include("Pizza", "Order")
    end
  end
end
