require "spec_helper"

RSpec.describe "Qualified reference_to paths" do
  describe "path parsing" do
    it "parses 1-segment path" do
      result = Hecks::DSL::ReferencePathParser.parse(["Topping"])
      expect(result).to eq({ type: "Topping" })
    end

    it "parses 2-segment path as aggregate::entity" do
      result = Hecks::DSL::ReferencePathParser.parse(["Pizza", "Topping"])
      expect(result).to eq({ type: "Topping", aggregate: "Pizza" })
    end

    it "parses 3-segment path as domain::aggregate::entity" do
      result = Hecks::DSL::ReferencePathParser.parse(["Ordering", "Pizza", "Topping"])
      expect(result).to eq({ type: "Topping", aggregate: "Pizza", domain: "Ordering" })
    end

    it "rejects paths with more than 3 segments" do
      expect { Hecks::DSL::ReferencePathParser.parse(["A", "B", "C", "D"]) }
        .to raise_error(ArgumentError, /1-3 segments/)
    end
  end

  describe "Reference IR" do
    it "stores segments from DSL declaration" do
      ref = Hecks::DomainModel::Structure::Reference.new(
        name: :topping, type: "Topping", aggregate: "Pizza", segments: ["Pizza", "Topping"]
      )
      expect(ref.segments).to eq(["Pizza", "Topping"])
      expect(ref.aggregate).to eq("Pizza")
    end

    it "builds segments when not provided" do
      ref = Hecks::DomainModel::Structure::Reference.new(
        name: :invoice, type: "Invoice", domain: "Billing"
      )
      expect(ref.segments).to eq(["Billing", "Invoice"])
    end

    it "builds 3-segment path" do
      ref = Hecks::DomainModel::Structure::Reference.new(
        name: :topping, type: "Topping", aggregate: "Pizza", domain: "Ordering"
      )
      expect(ref.segments).to eq(["Ordering", "Pizza", "Topping"])
    end

    it "returns qualified_path" do
      ref = Hecks::DomainModel::Structure::Reference.new(
        name: :topping, type: "Topping", aggregate: "Pizza", segments: ["Pizza", "Topping"]
      )
      expect(ref.qualified_path).to eq("Pizza::Topping")
    end

    it "returns simple qualified_path for 1-segment" do
      ref = Hecks::DomainModel::Structure::Reference.new(name: :team, type: "Team")
      expect(ref.qualified_path).to eq("Team")
    end
  end

  describe "DSL integration" do
    it "builds a 2-segment intra-domain reference (aggregate::entity)" do
      domain = Hecks.domain "Shop" do
        aggregate "Pizza" do
          attribute :name, String
          entity("Topping") { attribute :label, String }
          command("CreatePizza") { attribute :name, String }
        end
        aggregate "Order" do
          attribute :qty, Integer
          reference_to "Pizza::Topping"
          command("PlaceOrder") { attribute :qty, Integer }
        end
      end
      ref = domain.aggregates.last.references.first
      expect(ref.type).to eq("Topping")
      expect(ref.aggregate).to eq("Pizza")
      expect(ref.segments).to eq(["Pizza", "Topping"])
      expect(ref.kind).to eq(:aggregation)
    end

    it "reclassifies 2-segment as cross-context when first segment is not a known aggregate" do
      domain = Hecks.domain "Shop" do
        aggregate "Order" do
          attribute :name, String
          reference_to "Billing::Invoice"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      ref = domain.aggregates.first.references.first
      expect(ref.kind).to eq(:cross_context)
      expect(ref.domain).to eq("Billing")
      expect(ref.type).to eq("Invoice")
    end

    it "builds a 3-segment cross-domain reference" do
      domain = Hecks.domain "Shop" do
        aggregate "Order" do
          attribute :name, String
          reference_to "Fulfillment::Shipment::TrackingInfo"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      ref = domain.aggregates.first.references.first
      expect(ref.kind).to eq(:cross_context)
      expect(ref.domain).to eq("Fulfillment")
      expect(ref.aggregate).to eq("Shipment")
      expect(ref.type).to eq("TrackingInfo")
    end

    it "classifies 2-segment as composition when same aggregate owns the entity" do
      domain = Hecks.domain "Shop" do
        aggregate "Pizza" do
          attribute :name, String
          entity("Topping") { attribute :label, String }
          reference_to "Pizza::Topping"
          command("CreatePizza") { attribute :name, String }
        end
      end
      ref = domain.aggregates.first.references.first
      expect(ref.kind).to eq(:composition)
    end

    it "preserves simple 1-segment references" do
      domain = Hecks.domain "Shop" do
        aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } }
        aggregate("Order") { reference_to "Pizza"; command("PlaceOrder") { attribute :qty, Integer } }
      end
      ref = domain.aggregates.last.references.first
      expect(ref.type).to eq("Pizza")
      expect(ref.aggregate).to be_nil
      expect(ref.domain).to be_nil
      expect(ref.kind).to eq(:aggregation)
      expect(ref.segments).to eq(["Pizza"])
    end
  end

  describe "validation" do
    it "rejects qualified path with unknown aggregate" do
      domain = Hecks.domain "Shop" do
        aggregate "Order" do
          attribute :name, String
          reference_to "Missing::Topping"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      v = Hecks::Validator.new(domain)
      # "Missing" is not a known aggregate, so it gets reclassified as cross-context
      # and skipped by ValidReferences (validated at boot by multi-domain validator)
      expect(v).to be_valid
    end

    it "rejects qualified path with known aggregate but unknown entity" do
      domain = Hecks.domain "Shop" do
        aggregate "Pizza" do
          attribute :name, String
          command("CreatePizza") { attribute :name, String }
        end
        aggregate "Order" do
          attribute :qty, Integer
          reference_to "Pizza::Nonexistent"
          command("PlaceOrder") { attribute :qty, Integer }
        end
      end
      v = Hecks::Validator.new(domain)
      expect(v).not_to be_valid
      expect(v.errors.first.to_s).to include("Nonexistent")
      expect(v.errors.first.to_s).to include("Pizza")
    end

    it "accepts qualified path with known aggregate and entity" do
      domain = Hecks.domain "Shop" do
        aggregate "Pizza" do
          attribute :name, String
          entity("Topping") { attribute :label, String }
          command("CreatePizza") { attribute :name, String }
        end
        aggregate "Order" do
          attribute :qty, Integer
          reference_to "Pizza::Topping"
          command("PlaceOrder") { attribute :qty, Integer }
        end
      end
      v = Hecks::Validator.new(domain)
      expect(v).to be_valid
    end
  end

  describe "DslSerializer round-trip" do
    it "serializes and re-parses 1-segment reference" do
      domain = Hecks.domain "Shop" do
        aggregate("Pizza") { attribute :name, String; command("CreatePizza") { attribute :name, String } }
        aggregate("Order") { reference_to "Pizza"; command("PlaceOrder") { attribute :qty, Integer } }
      end
      dsl = Hecks::DslSerializer.new(domain).serialize
      expect(dsl).to include('reference_to "Pizza"')
    end

    it "serializes 2-segment qualified reference" do
      domain = Hecks.domain "Shop" do
        aggregate "Pizza" do
          attribute :name, String
          entity("Topping") { attribute :label, String }
          command("CreatePizza") { attribute :name, String }
        end
        aggregate "Order" do
          attribute :qty, Integer
          reference_to "Pizza::Topping"
          command("PlaceOrder") { attribute :qty, Integer }
        end
      end
      dsl = Hecks::DslSerializer.new(domain).serialize
      expect(dsl).to include('reference_to "Pizza::Topping"')
    end

    it "serializes cross-domain reference" do
      domain = Hecks.domain "Shop" do
        aggregate "Order" do
          attribute :name, String
          reference_to "Billing::Invoice"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      dsl = Hecks::DslSerializer.new(domain).serialize
      expect(dsl).to include('reference_to "Billing::Invoice"')
    end

    it "serializes 3-segment reference" do
      domain = Hecks.domain "Shop" do
        aggregate "Order" do
          attribute :name, String
          reference_to "Fulfillment::Shipment::TrackingInfo"
          command("PlaceOrder") { attribute :name, String }
        end
      end
      dsl = Hecks::DslSerializer.new(domain).serialize
      expect(dsl).to include('reference_to "Fulfillment::Shipment::TrackingInfo"')
    end
  end

  describe "command-level qualified references" do
    it "supports qualified reference_to in commands" do
      domain = Hecks.domain "Shop" do
        aggregate "Pizza" do
          attribute :name, String
          entity("Topping") { attribute :label, String }
          command("CreatePizza") { attribute :name, String }
        end
        aggregate "Order" do
          attribute :qty, Integer
          command("PlaceOrder") do
            attribute :qty, Integer
            reference_to "Pizza::Topping"
          end
        end
      end
      ref = domain.aggregates.last.commands.first.references.first
      expect(ref.type).to eq("Topping")
      expect(ref.aggregate).to eq("Pizza")
      expect(ref.segments).to eq(["Pizza", "Topping"])
    end
  end
end
