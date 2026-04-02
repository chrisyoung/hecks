require "spec_helper"
require "hecks/concerns/mapping"

RSpec.describe Hecks::Concerns::Mapping do
  describe ".extensions_for" do
    it "returns the extension for a known concern" do
      expect(described_class.extensions_for(:privacy)).to eq([:pii])
      expect(described_class.extensions_for(:transparency)).to eq([:audit])
    end

    it "returns empty array for an unknown concern" do
      expect(described_class.extensions_for(:bogus)).to eq([])
    end
  end

  describe ".capabilities_for" do
    it "returns capabilities for a concern that has them" do
      expect(described_class.capabilities_for(:transparency)).to eq([:audit])
      expect(described_class.capabilities_for(:privacy)).to eq([:audit])
    end

    it "returns empty array for a concern with no capabilities" do
      expect(described_class.capabilities_for(:security)).to eq([])
    end
  end

  describe ".resolve" do
    it "returns both extensions and capabilities for a concern" do
      result = described_class.resolve(:transparency)
      expect(result[:extensions]).to eq([:audit])
      expect(result[:capabilities]).to eq([:audit])
    end
  end

  describe ".resolve_all" do
    it "deduplicates extensions and capabilities across multiple concerns" do
      result = described_class.resolve_all([:privacy, :transparency])
      expect(result[:extensions]).to eq([:pii, :audit])
      expect(result[:capabilities]).to eq([:audit])
    end

    it "returns empty arrays for empty input" do
      result = described_class.resolve_all([])
      expect(result[:extensions]).to eq([])
      expect(result[:capabilities]).to eq([])
    end
  end

  describe "VALID_CONCERNS" do
    it "includes all six world concerns" do
      expect(described_class::VALID_CONCERNS).to contain_exactly(
        :privacy, :transparency, :consent, :security, :equity, :sustainability
      )
    end
  end
end
