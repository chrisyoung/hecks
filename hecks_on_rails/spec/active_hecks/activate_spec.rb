require_relative "shared_setup"

RSpec.describe "ActiveHecks.activate" do
  include_context "active_hecks pizzas"

  it "adds ActiveModel::Naming to aggregates" do
    expect(PizzasDomain::Pizza).to respond_to(:model_name)
  end

  it "adds ActiveModel::Naming to value objects" do
    expect(PizzasDomain::Pizza::Topping).to respond_to(:model_name)
  end

  it "skips exception classes" do
    expect(PizzasDomain::InvariantError.ancestors).not_to include(ActiveHecks::DomainModelCompat)
    expect(PizzasDomain::ValidationError.ancestors).not_to include(ActiveHecks::DomainModelCompat)
  end
end
