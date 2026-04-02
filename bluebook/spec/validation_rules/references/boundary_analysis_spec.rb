require "spec_helper"

RSpec.describe Hecks::ValidationRules::References::BoundaryAnalysis do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    v.valid?
    v.warnings
  end

  def domain_with_refs(&block)
    Hecks.domain("TestDomain", &block)
  end

  describe "reference density" do
    it "warns when density exceeds 2.0" do
      # 7 refs / 3 aggs = density 2.33
      domain = domain_with_refs do
        aggregate "Order" do
          reference_to "Customer"
          reference_to "Product"
          command("PlaceOrder") { attribute :name, String }
        end

        aggregate "Customer" do
          reference_to "Order"
          reference_to "Product"
          command("CreateCustomer") { attribute :name, String }
        end

        aggregate "Product" do
          reference_to "Order"
          reference_to "Customer"
          reference_to "Order"
          command("CreateProduct") { attribute :name, String }
        end
      end

      warnings = validate(domain)
      expect(warnings).to include(a_string_matching(/Reference density.*exceeds threshold/))
    end

    it "does not warn when density is low" do
      domain = domain_with_refs do
        aggregate "Order" do
          reference_to "Customer"
          command("PlaceOrder") { attribute :name, String }
        end

        aggregate "Customer" do
          command("CreateCustomer") { attribute :name, String }
        end
      end

      warnings = validate(domain)
      expect(warnings).not_to include(a_string_matching(/Reference density/))
    end
  end

  describe "hub detection" do
    it "warns when one aggregate receives >50% of all references" do
      domain = domain_with_refs do
        aggregate "Hub" do
          command("CreateHub") { attribute :name, String }
        end

        aggregate "A" do
          reference_to "Hub"
          command("CreateA") { attribute :name, String }
        end

        aggregate "B" do
          reference_to "Hub"
          command("CreateB") { attribute :name, String }
        end

        aggregate "C" do
          reference_to "Hub"
          command("CreateC") { attribute :name, String }
        end
      end

      warnings = validate(domain)
      expect(warnings).to include(a_string_matching(/Hub is a hub aggregate/))
    end
  end

  describe "cycle detection" do
    it "warns when aggregates form a reference cycle" do
      domain = domain_with_refs do
        aggregate "A" do
          reference_to "B"
          command("CreateA") { attribute :name, String }
        end

        aggregate "B" do
          reference_to "C"
          command("CreateB") { attribute :name, String }
        end

        aggregate "C" do
          reference_to "A"
          command("CreateC") { attribute :name, String }
        end
      end

      warnings = validate(domain)
      expect(warnings).to include(a_string_matching(/Reference cycle detected/))
    end

    it "does not warn for acyclic references" do
      domain = domain_with_refs do
        aggregate "Order" do
          reference_to "Customer"
          command("PlaceOrder") { attribute :name, String }
        end

        aggregate "Customer" do
          command("CreateCustomer") { attribute :name, String }
        end
      end

      warnings = validate(domain)
      expect(warnings).not_to include(a_string_matching(/Reference cycle/))
    end
  end

  describe "single aggregate domain" do
    it "produces no warnings" do
      domain = domain_with_refs do
        aggregate "Solo" do
          command("CreateSolo") { attribute :name, String }
        end
      end

      warnings = validate(domain)
      boundary_warnings = warnings.select { |w| w.match?(/density|hub|cycle/i) }
      expect(boundary_warnings).to be_empty
    end
  end
end
