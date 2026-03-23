require "spec_helper"

RSpec.describe BillingDomain::Invoice::Commands::CreateInvoice do
  subject(:command) do
    described_class.new(pizza_id: "example", quantity: 1)
  end

  describe "#initialize" do
    it "creates a frozen command" do
      expect(command).to be_frozen
    end

    it "has pizza_id" do
      expect(command.pizza_id).not_to be_nil
    end

    it "has quantity" do
      expect(command.quantity).not_to be_nil
    end
  end
end
