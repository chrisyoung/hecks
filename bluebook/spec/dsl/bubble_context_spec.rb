require "spec_helper"

RSpec.describe "bubble_context DSL" do
  it "groups aggregates under a named context" do
    domain = Hecks.domain "ECommerce" do
      aggregate("Order") { attribute :total, Integer; command("CreateOrder") { attribute :total, Integer } }
      aggregate("Shipment") { attribute :tracking, String; command("CreateShipment") { attribute :tracking, String } }

      bubble_context "Fulfillment" do
        aggregate "Order"
        aggregate "Shipment"
      end
    end

    expect(domain.bubble_contexts.size).to eq(1)
    bc = domain.bubble_contexts.first
    expect(bc.name).to eq("Fulfillment")
    expect(bc.aggregate_names).to eq(["Order", "Shipment"])
  end

  it "supports multiple bubble contexts" do
    domain = Hecks.domain "ECommerce" do
      aggregate("Order") { attribute :total, Integer; command("CreateOrder") { attribute :total, Integer } }
      aggregate("Payment") { attribute :amount, Float; command("CreatePayment") { attribute :amount, Float } }
      aggregate("Shipment") { attribute :tracking, String; command("CreateShipment") { attribute :tracking, String } }

      bubble_context "Fulfillment" do
        aggregate "Order"
        aggregate "Shipment"
      end

      bubble_context "Billing" do
        aggregate "Payment"
      end
    end

    expect(domain.bubble_contexts.map(&:name)).to eq(["Fulfillment", "Billing"])
    expect(domain.bubble_contexts.last.aggregate_names).to eq(["Payment"])
  end

  it "allows an aggregate to appear in multiple bubble contexts" do
    domain = Hecks.domain "ECommerce" do
      aggregate("Order") { attribute :total, Integer; command("CreateOrder") { attribute :total, Integer } }

      bubble_context "Fulfillment" do
        aggregate "Order"
      end

      bubble_context "CustomerView" do
        aggregate "Order"
      end
    end

    names = domain.bubble_contexts.map(&:name)
    expect(names).to eq(["Fulfillment", "CustomerView"])
    expect(domain.bubble_contexts.all? { |bc| bc.aggregate_names.include?("Order") }).to be true
  end

  it "defaults to empty bubble contexts" do
    domain = Hecks.domain "Simple" do
      aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } }
    end

    expect(domain.bubble_contexts).to eq([])
  end

  it "round-trips through DslSerializer" do
    domain = Hecks.domain "ECommerce" do
      aggregate("Order") { attribute :total, Integer; command("CreateOrder") { attribute :total, Integer } }

      bubble_context "Fulfillment" do
        aggregate "Order"
      end
    end

    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include('bubble_context "Fulfillment"')
    expect(source).to include('aggregate "Order"')

    restored = eval(source)
    expect(restored.bubble_contexts.size).to eq(1)
    expect(restored.bubble_contexts.first.name).to eq("Fulfillment")
    expect(restored.bubble_contexts.first.aggregate_names).to eq(["Order"])
  end
end
