require "spec_helper"

RSpec.describe Hecks::ValidationRules::References::FanOut do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    v.valid?
    v.warnings
  end

  it "warns when an aggregate has 4 or more references" do
    domain = Hecks.domain "FanOutTest" do
      aggregate "Order" do
        reference_to "Customer"
        reference_to "Product"
        reference_to "Warehouse"
        reference_to "ShippingMethod"
        command("PlaceOrder") { attribute :name, String }
      end

      aggregate "Customer" do
        command("CreateCustomer") { attribute :name, String }
      end

      aggregate "Product" do
        command("CreateProduct") { attribute :name, String }
      end

      aggregate "Warehouse" do
        command("CreateWarehouse") { attribute :name, String }
      end

      aggregate "ShippingMethod" do
        command("CreateShippingMethod") { attribute :name, String }
      end
    end

    warnings = validate(domain)
    expect(warnings).to include(a_string_matching(/Order has 4 outgoing references/))
  end

  it "does not warn when below threshold" do
    domain = Hecks.domain "SmallRefs" do
      aggregate "Order" do
        reference_to "Customer"
        reference_to "Product"
        command("PlaceOrder") { attribute :name, String }
      end

      aggregate "Customer" do
        command("CreateCustomer") { attribute :name, String }
      end

      aggregate "Product" do
        command("CreateProduct") { attribute :name, String }
      end
    end

    warnings = validate(domain)
    expect(warnings).not_to include(a_string_matching(/outgoing references/))
  end
end
