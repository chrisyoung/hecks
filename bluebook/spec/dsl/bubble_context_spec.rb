require "spec_helper"

RSpec.describe "bubble_context DSL" do
  def domain_with_contexts
    Hecks.domain("ECommerce") do
      aggregate("Order") do
        attribute :name, String
        command("CreateOrder") { attribute :name, String }
      end

      aggregate("Shipment") do
        attribute :tracking, String
        command("CreateShipment") { attribute :tracking, String }
      end

      aggregate("Invoice") do
        attribute :amount, Float
        command("CreateInvoice") { attribute :amount, Float }
      end

      bubble_context "Fulfillment" do
        aggregate "Order"
        aggregate "Shipment"
        description "Handles order fulfillment and shipping"
      end

      bubble_context "Billing" do
        aggregate "Invoice"
      end
    end
  end

  describe "IR representation" do
    it "stores bubble contexts on the domain" do
      domain = domain_with_contexts
      expect(domain.bubble_contexts.size).to eq(2)
    end

    it "stores context name" do
      ctx = domain_with_contexts.bubble_contexts.first
      expect(ctx.name).to eq("Fulfillment")
    end

    it "stores aggregate names" do
      ctx = domain_with_contexts.bubble_contexts.first
      expect(ctx.aggregate_names).to eq(["Order", "Shipment"])
    end

    it "stores description" do
      ctx = domain_with_contexts.bubble_contexts.first
      expect(ctx.description).to eq("Handles order fulfillment and shipping")
    end

    it "defaults to empty bubble_contexts" do
      domain = Hecks.domain("Simple") do
        aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } }
      end
      expect(domain.bubble_contexts).to eq([])
    end
  end

  describe "validation" do
    it "raises when bubble context references unknown aggregate" do
      expect {
        Hecks.domain("Bad") do
          aggregate("Order") do
            attribute :name, String
            command("CreateOrder") { attribute :name, String }
          end

          bubble_context "Fulfillment" do
            aggregate "NonExistent"
          end
        end
      }.to raise_error(Hecks::ValidationError, /unknown aggregate 'NonExistent'/)
    end
  end

  describe "bubble context without block" do
    it "creates an empty bubble context" do
      domain = Hecks.domain("Minimal") do
        aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } }
        bubble_context "Empty"
      end
      ctx = domain.bubble_contexts.first
      expect(ctx.name).to eq("Empty")
      expect(ctx.aggregate_names).to eq([])
      expect(ctx.description).to be_nil
    end
  end
end
