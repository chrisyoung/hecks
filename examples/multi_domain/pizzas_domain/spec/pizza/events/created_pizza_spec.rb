require "spec_helper"

RSpec.describe PizzasDomain::Pizza::Events::CreatedPizza do
  subject(:event) do
    described_class.new(name: "example", style: "example", price: 1.0)
  end

  describe "#initialize" do
    it "creates a frozen event" do
      expect(event).to be_frozen
    end

    it "records occurred_at" do
      expect(event.occurred_at).to be_a(Time)
    end
  end
end
