require "spec_helper"

RSpec.describe "Boundary Analysis Validators" do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    [v.valid?, v.errors, v.warnings]
  end

  describe "References::BoundaryAnalysis" do
    it "warns about hub aggregates referenced by 3+ others" do
      domain = Hecks.domain("Test") do
        aggregate("Hub") { attribute :name, String; command("CreateHub") { attribute :name, String } }
        aggregate("A") { reference_to "Hub"; command("CreateA") { attribute :name, String } }
        aggregate("B") { reference_to "Hub"; command("CreateB") { attribute :name, String } }
        aggregate("C") { reference_to "Hub"; command("CreateC") { attribute :name, String } }
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Hub") && w.include?("hub aggregate") }).to be true
    end

    it "detects reference cycles via DFS" do
      domain = Hecks.domain("Test") do
        aggregate("X") { reference_to "Y"; command("CreateX") { attribute :name, String } }
        aggregate("Y") { reference_to "Z"; command("CreateY") { attribute :name, String } }
        aggregate("Z") { reference_to "X"; command("CreateZ") { attribute :name, String } }
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("cycle") }).to be true
    end

    it "does not warn about simple linear references" do
      domain = Hecks.domain("Test") do
        aggregate("Order") { reference_to "Product"; command("PlaceOrder") { attribute :name, String } }
        aggregate("Product") { attribute :name, String; command("CreateProduct") { attribute :name, String } }
      end
      _, _, warnings = validate(domain)
      boundary_warnings = warnings.select { |w| w.include?("density") || w.include?("hub") || w.include?("cycle") }
      expect(boundary_warnings).to be_empty
    end
  end

  describe "References::FanOut" do
    it "warns when aggregate has 4+ outgoing references" do
      domain = Hecks.domain("Test") do
        aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } }
        aggregate("Customer") { attribute :name, String; command("CreateCustomer") { attribute :name, String } }
        aggregate("Delivery") { attribute :name, String; command("CreateDelivery") { attribute :name, String } }
        aggregate("Payment") { attribute :name, String; command("CreatePayment") { attribute :name, String } }
        aggregate("Order") do
          reference_to "Pizza"
          reference_to "Customer"
          reference_to "Delivery"
          reference_to "Payment"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("Order") && w.include?("fan-out") }).to be true
    end

    it "does not warn under threshold" do
      domain = Hecks.domain("Test") do
        aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } }
        aggregate("Order") do
          reference_to "Pizza"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("fan-out") }).to be true
    end
  end
end
