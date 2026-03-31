require_relative "shared_setup"

RSpec.describe "ActiveHecks::AggregateCompat" do
  include_context "active_hecks pizzas"
  subject(:pizza) { PizzasDomain::Pizza.new(name: "Margherita") }

  it "#to_param returns the id" do
    expect(pizza.to_param).to eq(pizza.id)
  end

  it "#to_key returns [id] when persisted" do
    expect(pizza.to_key).to eq([pizza.id])
  end

  it "#persisted? is true when id is present" do
    expect(pizza).to be_persisted
  end

  it "#new_record? is false when persisted" do
    expect(pizza).not_to be_new_record
  end

  it "#destroyed? defaults to false" do
    expect(pizza).not_to be_destroyed
  end

  it "#errors returns an ActiveModel::Errors" do
    expect(pizza.errors).to be_a(ActiveModel::Errors)
  end

  it "model_name strips the domain module prefix" do
    expect(PizzasDomain::Pizza.model_name.to_s).to eq("Pizza")
  end

  it "model_name provides singular and plural" do
    expect(PizzasDomain::Pizza.model_name.singular).to eq("pizza")
    expect(PizzasDomain::Pizza.model_name.plural).to eq("pizzas")
  end
end
