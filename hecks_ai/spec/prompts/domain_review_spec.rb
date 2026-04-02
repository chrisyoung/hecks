require "spec_helper"

RSpec.describe Hecks::AI::Prompts::DomainReview do
  describe "SYSTEM_PROMPT" do
    it "contains DDD reviewer role" do
      expect(described_class::SYSTEM_PROMPT).to include("Domain-Driven Design reviewer")
    end

    it "defines severity levels" do
      expect(described_class::SYSTEM_PROMPT).to include("critical")
      expect(described_class::SYSTEM_PROMPT).to include("warning")
      expect(described_class::SYSTEM_PROMPT).to include("suggestion")
    end

    it "covers aggregate boundaries" do
      expect(described_class::SYSTEM_PROMPT).to include("Aggregate boundaries")
    end

    it "covers command design" do
      expect(described_class::SYSTEM_PROMPT).to include("Command design")
    end

    it "covers value objects" do
      expect(described_class::SYSTEM_PROMPT).to include("Value objects")
    end
  end

  describe "TOOL_SCHEMA" do
    subject(:schema) { described_class::TOOL_SCHEMA }

    it "is named review_domain" do
      expect(schema[:name]).to eq("review_domain")
    end

    it "requires overall_score, summary, and findings" do
      required = schema[:input_schema][:required]
      expect(required).to include("overall_score", "summary", "findings")
    end

    it "defines findings as an array" do
      findings = schema[:input_schema][:properties][:findings]
      expect(findings[:type]).to eq("array")
    end

    it "defines severity as an enum" do
      finding_props = schema[:input_schema][:properties][:findings][:items][:properties]
      expect(finding_props[:severity][:enum]).to eq(%w[critical warning suggestion])
    end
  end
end
