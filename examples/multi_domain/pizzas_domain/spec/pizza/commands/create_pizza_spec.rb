require "spec_helper"

RSpec.describe PizzasDomain::Pizza::Commands::CreatePizza do
  subject(:command) do
    described_class.new(name: "example", style: "example", price: 1.0)
  end

  describe "#initialize" do
    it "creates a frozen command" do
      expect(command).to be_frozen
    end

    it "has name" do
      expect(command.name).not_to be_nil
    end

    it "has style" do
      expect(command.style).not_to be_nil
    end

    it "has price" do
      expect(command.price).not_to be_nil
    end
  end
end
