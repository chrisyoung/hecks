require "spec_helper"

RSpec.describe "Naming Analysis Validators" do
  def validate(domain)
    v = Hecks::Validator.new(domain)
    [v.valid?, v.errors, v.warnings]
  end

  describe "Naming::IntentionRevealingNames" do
    it "warns about generic aggregate names" do
      domain = Hecks.domain("Test") do
        aggregate("DataItem") do
          attribute :name, String
          command("CreateDataItem") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("DataItem") && w.include?("generic") }).to be true
    end

    it "warns about generic attribute names" do
      domain = Hecks.domain("Test") do
        aggregate("Order") do
          attribute :data, String
          command("CreateOrder") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("data") && w.include?("generic") }).to be true
    end

    it "does not warn about domain-specific names" do
      domain = Hecks.domain("Test") do
        aggregate("Invoice") do
          attribute :amount, Integer
          command("CreateInvoice") { attribute :amount, Integer }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.none? { |w| w.include?("generic") }).to be true
    end
  end

  describe "Naming::EventNaming" do
    it "warns when event name is not past tense" do
      domain = Hecks.domain("Test") do
        aggregate("Pizza") do
          attribute :name, String
          command("CreatePizza") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      # CreatedPizza is auto-generated, which IS past tense -- should not warn
      event_warnings = warnings.select { |w| w.include?("past tense") }
      expect(event_warnings).to be_empty
    end

    it "suggests past tense form in hint" do
      # Build domain with a non-past-tense event manually
      agg = Hecks::DomainModel::Structure::Aggregate.new(
        name: "Order",
        attributes: [Hecks::DomainModel::Structure::Attribute.new(name: :name, type: String)],
        events: [Hecks::DomainModel::Behavior::DomainEvent.new(name: "PlaceOrder", attributes: [])]
      )
      domain = Hecks::DomainModel::Structure::Domain.new(name: "Test", aggregates: [agg])
      _, _, warnings = validate(domain)
      event_warnings = warnings.select { |w| w.include?("past tense") }
      expect(event_warnings).not_to be_empty
      expect(event_warnings.first.hint).to include("PlacedOrder")
    end
  end

  describe "Naming::AttributeNaming" do
    it "warns about Hungarian notation prefixes" do
      domain = Hecks.domain("Test") do
        aggregate("Widget") do
          attribute :str_name, String
          command("CreateWidget") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("str_") && w.include?("Hungarian") }).to be true
    end

    it "warns about redundant type suffixes" do
      domain = Hecks.domain("Test") do
        aggregate("Widget") do
          attribute :name_string, String
          command("CreateWidget") { attribute :name, String }
        end
      end
      _, _, warnings = validate(domain)
      expect(warnings.any? { |w| w.include?("_string") && w.include?("suffix") }).to be true
    end

    it "does not warn about clean attribute names" do
      domain = Hecks.domain("Test") do
        aggregate("Widget") do
          attribute :title, String
          attribute :count, Integer
          command("CreateWidget") { attribute :title, String }
        end
      end
      _, _, warnings = validate(domain)
      attr_warnings = warnings.select { |w| w.include?("Hungarian") || w.include?("suffix") }
      expect(attr_warnings).to be_empty
    end
  end
end
