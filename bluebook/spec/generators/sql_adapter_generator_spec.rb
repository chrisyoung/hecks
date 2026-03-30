require "spec_helper"

RSpec.describe Hecks::Generators::SQL::SqlAdapterGenerator do
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

    it "takes a Sequel db in initialize" do
      expect(code).to include("def initialize(db)")
      expect(code).to include("@db = db")
    end

    it "implements find using Sequel dataset" do
      expect(code).to include("def find(id)")
      expect(code).to include("@db[:pizzas].where(id: id).first")
    end

    it "implements save with upsert" do
      expect(code).to include("def save(pizza)")
      expect(code).to include("@db[:pizzas].insert(")
      expect(code).to include("@db[:pizzas].where(id: pizza.id).update(")
    end

    it "implements delete using Sequel" do
      expect(code).to include("def delete(id)")
      expect(code).to include("@db[:pizzas].where(id: id).delete")
    end

    it "implements all" do
      expect(code).to include("def all")
      expect(code).to include("@db[:pizzas].all")
    end

    it "implements count" do
      expect(code).to include("def count")
      expect(code).to include("@db[:pizzas].count")
    end

    it "handles value object join tables" do
      expect(code).to include("pizzas_toppings")
      expect(code).to include("Pizza::Topping.new")
    end

    it "implements query using Sequel dataset" do
      expect(code).to include("def query(conditions: {}")
      expect(code).to include("@db[:pizzas]")
      expect(code).to include("ds.where")
      expect(code).to include("ds.order")
      expect(code).to include("ds.limit")
      expect(code).to include("ds.offset")
    end
  end
end
