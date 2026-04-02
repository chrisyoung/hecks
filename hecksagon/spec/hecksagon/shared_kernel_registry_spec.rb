require "spec_helper"

RSpec.describe Hecksagon::SharedKernelRegistry do
  before { described_class.clear! }
  after  { described_class.clear! }

  describe ".register and .types_for" do
    it "stores and retrieves types for a domain" do
      described_class.register("Pricing", ["Money", "Currency"])
      expect(described_class.types_for("Pricing")).to eq(["Money", "Currency"])
    end

    it "returns empty array for unregistered domain" do
      expect(described_class.types_for("Unknown")).to eq([])
    end
  end

  describe ".kernel?" do
    it "returns true for registered domains" do
      described_class.register("Pricing", ["Money"])
      expect(described_class.kernel?("Pricing")).to be true
    end

    it "returns false for unregistered domains" do
      expect(described_class.kernel?("Pricing")).to be false
    end
  end

  describe ".all" do
    it "returns all registered domain names" do
      described_class.register("Pricing", ["Money"])
      described_class.register("Common", ["Address"])
      expect(described_class.all).to contain_exactly("Pricing", "Common")
    end
  end

  describe ".clear!" do
    it "removes all registrations" do
      described_class.register("Pricing", ["Money"])
      described_class.clear!
      expect(described_class.all).to be_empty
    end
  end
end
