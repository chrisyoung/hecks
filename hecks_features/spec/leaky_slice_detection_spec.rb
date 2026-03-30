require "spec_helper"
require "hecks_features"

RSpec.describe HecksFeatures::LeakySliceDetection do
  context "aggregate-scoped policy triggers command on another aggregate" do
    let(:domain) do
      Hecks.domain("Leaky") do
        aggregate "Order" do
          attribute :total, Float
          command("PlaceOrder") { attribute :total, Float }

          policy "ChargePayment" do
            on "PlacedOrder"
            trigger "ChargeCard"
          end
        end

        aggregate "Payment" do
          attribute :amount, Float
          command("ChargeCard") { attribute :amount, Float }
        end
      end
    end

    it "warns about the cross-aggregate policy" do
      rule = described_class.new(domain)
      expect(rule.warnings.size).to eq(1)
      expect(rule.warnings.first).to include("ChargePayment")
      expect(rule.warnings.first).to include("Order")
      expect(rule.warnings.first).to include("Payment")
      expect(rule.warnings.first).to include("domain-level policy")
    end

    it "returns no errors" do
      expect(described_class.new(domain).errors).to be_empty
    end
  end

  context "domain-level policy (not leaky)" do
    let(:domain) do
      Hecks.domain("Clean") do
        aggregate "Order" do
          attribute :total, Float
          command("PlaceOrder") { attribute :total, Float }
        end

        aggregate "Payment" do
          attribute :amount, Float
          command("ChargeCard") { attribute :amount, Float }
        end

        policy "ChargePayment" do
          on "PlacedOrder"
          trigger "ChargeCard"
        end
      end
    end

    it "produces no warnings" do
      expect(described_class.new(domain).warnings).to be_empty
    end
  end

  context "aggregate-scoped policy triggers command on same aggregate" do
    let(:domain) do
      Hecks.domain("Internal") do
        aggregate "Account" do
          attribute :balance, Float
          command("Deposit") { attribute :amount, Float }
          command("RecordInterest") { attribute :amount, Float }

          policy "AccrueInterest" do
            on "Deposited"
            trigger "RecordInterest"
          end
        end
      end
    end

    it "produces no warnings (same aggregate)" do
      expect(described_class.new(domain).warnings).to be_empty
    end
  end
end
