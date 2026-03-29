require "spec_helper"

RSpec.describe HecksTemplating::TypeContract do
  describe ".go" do
    it "maps String to string" do
      expect(described_class.go("String")).to eq("string")
    end

    it "maps Integer to int64" do
      expect(described_class.go("Integer")).to eq("int64")
    end

    it "defaults unknown types to string" do
      expect(described_class.go("Widget")).to eq("string")
    end
  end

  describe ".sql" do
    it "maps String to VARCHAR(255)" do
      expect(described_class.sql("String")).to eq("VARCHAR(255)")
    end

    it "maps Integer to INTEGER" do
      expect(described_class.sql("Integer")).to eq("INTEGER")
    end

    it "maps Float to REAL" do
      expect(described_class.sql("Float")).to eq("REAL")
    end

    it "defaults unknown types to TEXT" do
      expect(described_class.sql("Widget")).to eq("TEXT")
    end
  end

  describe ".json" do
    it "maps Integer to integer" do
      expect(described_class.json("Integer")).to eq("integer")
    end

    it "maps Boolean to boolean" do
      expect(described_class.json("Boolean")).to eq("boolean")
    end
  end

  describe ".openapi" do
    it "maps Float to number" do
      expect(described_class.openapi("Float")).to eq("number")
    end
  end

  describe ".go_zero_value" do
    it "returns empty string for string" do
      expect(described_class.go_zero_value("string")).to eq('""')
    end

    it "returns 0 for int64" do
      expect(described_class.go_zero_value("int64")).to eq("0")
    end

    it "returns false for bool" do
      expect(described_class.go_zero_value("bool")).to eq("false")
    end
  end
end
