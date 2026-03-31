require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Commands::CommandMethods do
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

  before do
    @app = Hecks.load(domain)
  end

  describe "create commands" do
    it "creates and persists an aggregate" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      expect(pizza.name).to eq("Margherita")
      expect(PizzasDomain::Pizza.find(pizza.id)).not_to be_nil
    end

    it "fires a domain event" do
      PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      expect(@app.events.size).to eq(1)
      expect(@app.events.first.class.name).to include("CreatedPizza")
    end

    it "sets timestamps" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      expect(pizza.created_at).to be_a(Time)
      expect(pizza.updated_at).to be_a(Time)
    end
  end

  describe "update commands" do
    it "dispatches and persists" do
      pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
      seed = PizzasDomain::Order.new(id: pizza.id, pizza_id: pizza.id, quantity: 1)
      seed.save
      order = PizzasDomain::Order.place(pizza_id: pizza.id, quantity: 3)
      expect(order.quantity).to eq(3)
      expect(PizzasDomain::Order.find(order.id)).not_to be_nil
    end
  end
end
