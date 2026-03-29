require "spec_helper"

RSpec.describe Hecks::CrossDomainQuery do
  before(:all) do
    d1 = Hecks.domain "Inventory" do
      aggregate "Product" do
        attribute :name, String
        attribute :price, Float

        command "CreateProduct" do
          attribute :name, String
          attribute :price, Float
        end
      end
    end

    d2 = Hecks.domain "Shipping" do
      aggregate "Shipment" do
        attribute :product_id, String
        attribute :destination, String

        command "CreateShipment" do
          attribute :product_id, String
          attribute :destination, String
        end
      end
    end

    @app1 = Hecks.load(d1, force: true)
    @app2 = Hecks.load(d2, force: true)

    Hecks.cross_domain_query "ProductShipments" do |product_id:|
      product   = from("Inventory", "Product").find(product_id)
      shipments = from("Shipping", "Shipment").all.select { |s| s.product_id == product_id }
      { product: product, shipments: shipments }
    end
  end

  it "registers a cross-domain query" do
    expect(Hecks.cross_domain_queries["ProductShipments"]).not_to be_nil
  end

  it "resolves aggregates across domains" do
    product = InventoryDomain::Product.create(name: "Widget", price: 9.99)
    ShippingDomain::Shipment.create(product_id: product.id, destination: "NYC")
    ShippingDomain::Shipment.create(product_id: product.id, destination: "LA")

    result = Hecks.query("ProductShipments", product_id: product.id)
    expect(result[:product].name).to eq("Widget")
    expect(result[:shipments].size).to eq(2)
  end

  it "raises for unknown query" do
    expect {
      Hecks.query("NonExistent", foo: "bar")
    }.to raise_error(Hecks::Error, /Unknown cross-domain query/)
  end
end
