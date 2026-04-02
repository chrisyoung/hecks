require "spec_helper"

RSpec.describe "Hecksagon capabilities DSL" do
  describe "email.privacy syntax" do
    let(:hex) do
      Hecks.hecksagon do
        capabilities "Customer" do
          email.privacy
          ssn.privacy.searchable
        end
      end
    end

    it "expands .privacy into pii, encrypted, masked tags" do
      caps = hex.aggregate_capabilities["Customer"]
      expect(caps["email"]).to include(:pii, :encrypted, :masked)
    end

    it "supports chaining additional tags" do
      caps = hex.aggregate_capabilities["Customer"]
      expect(caps["ssn"]).to include(:pii, :encrypted, :masked, :searchable)
    end

    it "returns PII attributes for an aggregate" do
      expect(hex.pii_attributes("Customer")).to eq(["email", "ssn"])
    end

    it "returns empty array for aggregate without PII" do
      expect(hex.pii_attributes("Order")).to eq([])
    end
  end

  describe "backward-compatible capability. prefix" do
    let(:hex) do
      Hecks.hecksagon do
        capabilities "Account" do
          capability.token.privacy
        end
      end
    end

    it "works with the capability. prefix" do
      caps = hex.aggregate_capabilities["Account"]
      expect(caps["token"]).to include(:pii, :encrypted, :masked)
    end
  end
end
