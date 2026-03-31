require_relative "shared_setup"

RSpec.describe "ActiveHecks::ValidationWiring" do
  include_context "active_hecks pizzas"

  it "wires DSL presence validation to ActiveModel" do
    blank = PizzasDomain::Pizza.new(name: "")
    expect(blank).not_to be_valid
    expect(blank.errors[:name]).to include("can't be blank")
  end

  it "passes validation for valid objects" do
    pizza = PizzasDomain::Pizza.new(name: "Margherita")
    expect(pizza).to be_valid
  end

  it "returns false for nil values" do
    pizza = PizzasDomain::Pizza.new(name: nil)
    expect(pizza).not_to be_valid
  end

  it "clears errors on re-validation" do
    pizza = PizzasDomain::Pizza.new(name: "Margherita")
    pizza.valid?
    expect(pizza.errors).to be_empty
  end

  it "makes validates available as a class method" do
    expect(PizzasDomain::Pizza).to respond_to(:validates)
  end

  it "allows constructing invalid objects" do
    expect { PizzasDomain::Pizza.new(name: "") }.not_to raise_error
  end
end
