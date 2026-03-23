require "spec_helper"

RSpec.describe Hecks::Generators::SqlAdapterGenerator do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  let(:aggregate) { domain.aggregates.first }
  subject(:generator) { described_class.new(aggregate, domain_module: "PizzasDomain") }

  describe "#generate" do
    let(:code) { generator.generate }

    it "defines the SQL repository class" do
      expect(code).to include("class PizzaSqlRepository")
    end

    it "includes the port" do
      expect(code).to include("include Ports::PizzaRepository")
    end

    it "takes a connection in initialize" do
      expect(code).to include("def initialize(connection)")
    end

    it "implements find" do
      expect(code).to include("def find(id)")
      expect(code).to include("SELECT * FROM pizzas WHERE id = ?")
    end

    it "implements save with upsert" do
      expect(code).to include("def save(pizza)")
      expect(code).to include("INSERT INTO pizzas")
      expect(code).to include("UPDATE pizzas SET")
    end

    it "implements delete" do
      expect(code).to include("def delete(id)")
      expect(code).to include("DELETE FROM pizzas WHERE id = ?")
    end

    it "implements all" do
      expect(code).to include("def all")
    end

    it "implements count" do
      expect(code).to include("def count")
    end

    it "handles value object join tables" do
      expect(code).to include("pizzas_toppings")
      expect(code).to include("Pizza::Topping.new")
    end

    it "implements query using Sequel dataset builder" do
      expect(code).to include("def query(conditions: {}, order_key: nil, order_direction: :asc, limit: nil, offset: nil)")
      expect(code).to include("Sequel.sqlite[:pizzas]")
      expect(code).to include("ds.where(conditions)")
      expect(code).to include("ds.order")
      expect(code).to include("ds.limit")
      expect(code).to include("ds.offset")
      expect(code).to include("ds.sql")
    end
  end
end
