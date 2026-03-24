require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Persistence::CollectionMethods do
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

  before do
    @app = Hecks.load(domain)
    @pizza = PizzasDomain::Pizza.create(name: "Margherita")
  end

  it "defines accessor method for list attributes" do
    expect(@pizza).to respond_to(:toppings)
  end

  it "returns a CollectionProxy" do
    expect(@pizza.toppings).to be_a(Hecks::Persistence::CollectionProxy)
  end

  it "starts with empty collection" do
    expect(@pizza.toppings.count).to eq(0)
    expect(@pizza.toppings).to be_empty
  end

  it "creates items that persist through find" do
    @pizza.toppings.create(name: "Mozzarella", amount: 2)
    found = PizzasDomain::Pizza.find(@pizza.id)
    expect(found.toppings.count).to eq(1)
    expect(found.toppings.first.name).to eq("Mozzarella")
    expect(found.toppings.first.amount).to eq(2)
  end

  it "supports creating multiple items" do
    @pizza.toppings.create(name: "Mozzarella", amount: 2)
    @pizza.toppings.create(name: "Basil", amount: 1)
    found = PizzasDomain::Pizza.find(@pizza.id)
    expect(found.toppings.count).to eq(2)
    expect(found.toppings.map(&:name)).to contain_exactly("Mozzarella", "Basil")
  end

  it "deletes items and persists the change" do
    @pizza.toppings.create(name: "Mozzarella", amount: 2)
    @pizza.toppings.create(name: "Basil", amount: 1)
    found = PizzasDomain::Pizza.find(@pizza.id)
    basil = found.toppings.find { |t| t.name == "Basil" }
    found.toppings.delete(basil)
    reloaded = PizzasDomain::Pizza.find(@pizza.id)
    expect(reloaded.toppings.count).to eq(1)
    expect(reloaded.toppings.first.name).to eq("Mozzarella")
  end

  it "clears all items" do
    @pizza.toppings.create(name: "A", amount: 1)
    @pizza.toppings.create(name: "B", amount: 2)
    found = PizzasDomain::Pizza.find(@pizza.id)
    found.toppings.clear
    reloaded = PizzasDomain::Pizza.find(@pizza.id)
    expect(reloaded.toppings).to be_empty
  end

  it "CollectionItem delegates to underlying value object" do
    @pizza.toppings.create(name: "Mozzarella", amount: 2)
    found = PizzasDomain::Pizza.find(@pizza.id)
    item = found.toppings.first
    expect(item.name).to eq("Mozzarella")
    expect(item.amount).to eq(2)
    expect(item.frozen?).to be true
  end

  it "CollectionItem.delete removes from parent" do
    @pizza.toppings.create(name: "Mozzarella", amount: 2)
    found = PizzasDomain::Pizza.find(@pizza.id)
    found.toppings.first.delete
    reloaded = PizzasDomain::Pizza.find(@pizza.id)
    expect(reloaded.toppings).to be_empty
  end
end
