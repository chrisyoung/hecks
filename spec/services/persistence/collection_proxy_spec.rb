require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Services::Persistence::CollectionProxy do
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
    Hecks.load_domain(domain)
    @app = Hecks::Services::Application.new(domain)
    @pizza = PizzasDomain::Pizza.create(name: "Margherita")
  end

  describe "#create" do
    it "adds an item and persists" do
      @pizza.toppings.create(name: "Mozzarella", amount: 2)
      found = PizzasDomain::Pizza.find(@pizza.id)
      expect(found.toppings.count).to eq(1)
      expect(found.toppings.first.name).to eq("Mozzarella")
    end
  end

  describe "#delete" do
    it "removes an item and persists" do
      @pizza.toppings.create(name: "Mozzarella", amount: 2)
      @pizza.toppings.create(name: "Basil", amount: 1)
      found = PizzasDomain::Pizza.find(@pizza.id)
      basil = found.toppings.find { |t| t.name == "Basil" }
      found.toppings.delete(basil)
      reloaded = PizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings.count).to eq(1)
    end
  end

  describe "#clear" do
    it "removes all items" do
      @pizza.toppings.create(name: "Mozzarella", amount: 2)
      @pizza.toppings.create(name: "Basil", amount: 1)
      found = PizzasDomain::Pizza.find(@pizza.id)
      found.toppings.clear
      reloaded = PizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings).to be_empty
    end
  end

  describe "Enumerable" do
    before do
      @pizza.toppings.create(name: "Mozzarella", amount: 2)
      @pizza.toppings.create(name: "Basil", amount: 1)
      @found = PizzasDomain::Pizza.find(@pizza.id)
    end

    it "#count returns the size" do
      expect(@found.toppings.count).to eq(2)
    end

    it "#first returns the first item" do
      expect(@found.toppings.first.name).not_to be_nil
    end

    it "#last returns the last item" do
      expect(@found.toppings.last.name).not_to be_nil
    end

    it "#empty? returns false for non-empty" do
      expect(@found.toppings).not_to be_empty
    end

    it "#map iterates over items" do
      names = @found.toppings.map(&:name)
      expect(names).to contain_exactly("Mozzarella", "Basil")
    end
  end

  describe "CollectionItem" do
    it "delegates methods to the underlying object" do
      @pizza.toppings.create(name: "Mozzarella", amount: 2)
      found = PizzasDomain::Pizza.find(@pizza.id)
      item = found.toppings.first
      expect(item.name).to eq("Mozzarella")
      expect(item.amount).to eq(2)
    end

    it "#delete removes from collection" do
      @pizza.toppings.create(name: "Mozzarella", amount: 2)
      found = PizzasDomain::Pizza.find(@pizza.id)
      found.toppings.first.delete
      reloaded = PizzasDomain::Pizza.find(@pizza.id)
      expect(reloaded.toppings).to be_empty
    end
  end
end
