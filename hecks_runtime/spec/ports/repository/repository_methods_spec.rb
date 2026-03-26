require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Persistence::RepositoryMethods do
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
  end

  describe ".bind" do
    it "sets the repo on the class" do
      expect(PizzasDomain::Pizza.instance_variable_get(:@__hecks_repo__)).not_to be_nil
    end
  end

  describe "class methods" do
    before do
      PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
    end

    it ".find returns an aggregate by id" do
      pizza = PizzasDomain::Pizza.first
      found = PizzasDomain::Pizza.find(pizza.id)
      expect(found.name).to eq(pizza.name)
    end

    it ".find returns nil for unknown id" do
      expect(PizzasDomain::Pizza.find("nonexistent")).to be_nil
    end

    it ".all returns all aggregates" do
      expect(PizzasDomain::Pizza.all.size).to eq(2)
    end

    it ".count returns the count" do
      expect(PizzasDomain::Pizza.count).to eq(2)
    end

    it ".first returns the first aggregate" do
      expect(PizzasDomain::Pizza.first).not_to be_nil
    end

    it ".last returns the last aggregate" do
      expect(PizzasDomain::Pizza.last).not_to be_nil
    end

    it ".delete removes an aggregate" do
      pizza = PizzasDomain::Pizza.first
      PizzasDomain::Pizza.delete(pizza.id)
      expect(PizzasDomain::Pizza.count).to eq(1)
    end

    it ".create sets timestamps" do
      pizza = PizzasDomain::Pizza.create(name: "New", style: "Fresh")
      expect(pizza.created_at).to be_a(Time)
      expect(pizza.updated_at).to be_a(Time)
    end
  end

  describe "instance methods" do
    it "#save persists the aggregate" do
      pizza = PizzasDomain::Pizza.new(name: "Manual", style: "Test")
      pizza.save
      expect(PizzasDomain::Pizza.find(pizza.id).name).to eq("Manual")
    end

    it "#destroy removes the aggregate" do
      pizza = PizzasDomain::Pizza.create(name: "Temp", style: "Test")
      pizza.destroy
      expect(PizzasDomain::Pizza.find(pizza.id)).to be_nil
    end

    it "#update returns a new aggregate with changed attributes" do
      pizza = PizzasDomain::Pizza.create(name: "Old", style: "Test")
      updated = pizza.update(name: "New")
      expect(updated.name).to eq("New")
      expect(updated.id).to eq(pizza.id)
    end
  end
end
