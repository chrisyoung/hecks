require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::AggregateWiring do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end

        query "Classics" do
          where(style: "Classic")
        end

        scope :spicy, style: "Spicy"
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain)
  end

  it "binds RepositoryMethods (find, all, count, create)" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    expect(PizzasDomain::Pizza.find(pizza.id).name).to eq("Margherita")
    expect(PizzasDomain::Pizza.all.size).to eq(1)
    expect(PizzasDomain::Pizza.count).to eq(1)
  end

  it "binds CommandMethods (commands become class methods)" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    order = PizzasDomain::Order.place(pizza_id: pizza.id, quantity: 3)
    expect(order.quantity).to eq(3)
  end

  it "binds CollectionMethods (list attributes return CollectionProxy)" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    pizza.toppings.create(name: "Mozzarella", amount: 2)
    found = PizzasDomain::Pizza.find(pizza.id)
    expect(found.toppings.count).to eq(1)
  end

  it "binds ReferenceMethods (reference resolution)" do
    pizza = PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    order = PizzasDomain::Order.place(pizza_id: pizza.id, quantity: 3)
    expect(order.pizza.name).to eq("Margherita")
  end

  it "binds query objects from DSL" do
    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
    expect(PizzasDomain::Pizza.classics.map(&:name)).to eq(["Margherita"])
  end

  it "binds scopes" do
    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    PizzasDomain::Pizza.create(name: "Pepperoni", style: "Spicy")
    expect(PizzasDomain::Pizza.spicy.map(&:name)).to eq(["Pepperoni"])
  end

  it "fires events on commands" do
    PizzasDomain::Pizza.create(name: "Margherita", style: "Classic")
    expect(@app.events.size).to eq(1)
    expect(@app.events.first.class.name).to include("CreatedPizza")
  end

  it "instance methods: save, update, destroy" do
    pizza = PizzasDomain::Pizza.create(name: "Old", style: "Classic")
    updated = pizza.update(name: "New")
    expect(updated.name).to eq("New")
    expect(updated.id).to eq(pizza.id)
    updated.destroy
    expect(PizzasDomain::Pizza.find(pizza.id)).to be_nil
  end
end
