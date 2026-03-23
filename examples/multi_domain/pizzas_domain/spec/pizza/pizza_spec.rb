require "spec_helper"

RSpec.describe PizzasDomain::Pizza do
  subject(:pizza) do
    described_class.new(name: "example", style: "example", price: 1.0)
  end

  describe "#initialize" do
    it "creates a Pizza with an id" do
      expect(pizza.id).not_to be_nil
    end

    it "has name" do
      expect(pizza.name).not_to be_nil
    end

    it "has style" do
      expect(pizza.style).not_to be_nil
    end

    it "has price" do
      expect(pizza.price).not_to be_nil
    end
  end


describe "equality" do
  it "is equal to another Pizza with the same id" do
    id = SecureRandom.uuid
    a = described_class.new(name: "example", style: "example", price: 1.0, id: id)
    b = described_class.new(name: "example", style: "example", price: 1.0, id: id)
    expect(a).to eq(b)
  end
end
end
