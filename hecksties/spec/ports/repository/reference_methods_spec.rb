require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Persistence::ReferenceMethods do
  let(:domain) do
    Hecks.domain "RefTest" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
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

  it "resolves a reference to the correct aggregate" do
    pizza = RefTestDomain::Pizza.create(name: "Margherita")
    cmd = RefTestDomain::Order.place(pizza: pizza.id, quantity: 3)
    order = RefTestDomain::Order.find(cmd.aggregate.id)
    resolved = order.pizza
    expect(resolved).not_to be_nil
    expect(resolved.name).to eq("Margherita")
    expect(resolved.id).to eq(pizza.id)
  end

  it "returns nil when ref_id is nil" do
    order = RefTestDomain::Order.create(pizza: nil, quantity: 1)
    expect(order.pizza).to be_nil
  end

  it "returns nil when referenced aggregate doesn't exist" do
    order = RefTestDomain::Order.create(pizza: "nonexistent-uuid", quantity: 1)
    expect(order.pizza).to be_nil
  end

  it "reflects changes to the referenced aggregate" do
    pizza = RefTestDomain::Pizza.create(name: "Old Name")
    cmd = RefTestDomain::Order.place(pizza: pizza.id, quantity: 1)
    order = RefTestDomain::Order.find(cmd.aggregate.id)
    pizza.update(name: "New Name")
    expect(order.pizza.name).to eq("New Name")
  end

  it "strips _id suffix for method name" do
    order = RefTestDomain::Order.create(pizza: nil, quantity: 1)
    expect(order).to respond_to(:pizza)
    expect(order).not_to respond_to(:pizza_id_ref)
  end
end
