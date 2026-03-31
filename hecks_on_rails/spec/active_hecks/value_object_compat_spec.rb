require_relative "shared_setup"

RSpec.describe "ActiveHecks::ValueObjectCompat" do
  include_context "active_hecks pizzas"
  subject(:topping) { PizzasDomain::Pizza::Topping.new(name: "Cheese", amount: 2) }

  it "#persisted? is false" do
    expect(topping).not_to be_persisted
  end

  it "#new_record? is true" do
    expect(topping).to be_new_record
  end

  it "#to_param is nil" do
    expect(topping.to_param).to be_nil
  end

  it "#to_key is nil" do
    expect(topping.to_key).to be_nil
  end

  it "#attributes returns a hash" do
    expect(topping.attributes["name"]).to eq("Cheese")
  end

  it "model_name strips the namespace" do
    expect(PizzasDomain::Pizza::Topping.model_name.to_s).to eq("Topping")
  end

  it "does not include validations (frozen objects)" do
    expect(topping).not_to respond_to(:valid?)
  end
end
