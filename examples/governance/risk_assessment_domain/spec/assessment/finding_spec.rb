require "spec_helper"

RSpec.describe RiskAssessmentDomain::Assessment::Finding do
  subject(:finding) { described_class.new(
          category: "example",
          severity: "low",
          description: "example"
        ) }

  it "is immutable" do
    expect(finding).to be_frozen
  end

  it "is equal when all attributes match" do
    other = described_class.new(
          category: "example",
          severity: "low",
          description: "example"
        )
    expect(finding).to eq(other)
  end
end
