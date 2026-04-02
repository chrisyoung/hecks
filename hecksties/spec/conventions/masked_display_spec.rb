require "spec_helper"

RSpec.describe Hecks::Conventions::MaskedDisplay do
  describe ".mask" do
    it "shows last 4 characters of a long string" do
      expect(described_class.mask("123-45-6789")).to eq("***-**-6789")
    end

    it "masks a credit card number" do
      expect(described_class.mask("4111111111111111")).to eq("************1111")
    end

    it "preserves hyphens and spaces in masked region" do
      expect(described_class.mask("123 456 7890")).to eq("*** *** 7890")
    end

    it "returns nil for nil" do
      expect(described_class.mask(nil)).to be_nil
    end

    it "returns empty string for empty string" do
      expect(described_class.mask("")).to eq("")
    end

    it "returns masked placeholder for short strings (4 or fewer chars)" do
      expect(described_class.mask("1234")).to eq("****")
      expect(described_class.mask("AB")).to eq("****")
    end

    it "handles a 5-character string" do
      expect(described_class.mask("12345")).to eq("*2345")
    end
  end

  describe ".masked_attributes" do
    let(:attr_class) { Hecks::DomainModel::Structure::Attribute }

    it "returns DSL-level masked attributes" do
      ssn_attr = attr_class.new(name: :ssn, type: String, masked: true)
      name_attr = attr_class.new(name: :name, type: String)
      agg = double("agg", attributes: [ssn_attr, name_attr])

      result = described_class.masked_attributes(agg)
      expect(result).to eq([:ssn])
    end

    it "returns hecksagon capability-tagged masked attributes" do
      name_attr = attr_class.new(name: :name, type: String)
      account_attr = attr_class.new(name: :account_number, type: String)
      agg = double("agg", attributes: [name_attr, account_attr])

      hex = Hecks.hecksagon do
        aggregate "Customer" do
          capability.account_number.masked
        end
      end

      result = described_class.masked_attributes(agg, hecksagon: hex, aggregate_name: "Customer")
      expect(result).to eq([:account_number])
    end

    it "deduplicates DSL and capability tags" do
      ssn_attr = attr_class.new(name: :ssn, type: String, masked: true)
      agg = double("agg", attributes: [ssn_attr])

      hex = Hecks.hecksagon do
        aggregate "Customer" do
          capability.ssn.masked
        end
      end

      result = described_class.masked_attributes(agg, hecksagon: hex, aggregate_name: "Customer")
      expect(result).to eq([:ssn])
    end
  end

  describe ".masked?" do
    let(:attr_class) { Hecks::DomainModel::Structure::Attribute }

    it "returns true for DSL-masked attribute" do
      attr = attr_class.new(name: :ssn, type: String, masked: true)
      expect(described_class.masked?(attr)).to be true
    end

    it "returns false for non-masked attribute" do
      attr = attr_class.new(name: :name, type: String)
      expect(described_class.masked?(attr)).to be false
    end

    it "returns true for capability-tagged masked attribute" do
      attr = attr_class.new(name: :ssn, type: String)
      hex = Hecks.hecksagon do
        aggregate "Customer" do
          capability.ssn.masked
        end
      end

      expect(described_class.masked?(attr, hecksagon: hex, aggregate_name: "Customer")).to be true
    end
  end
end
