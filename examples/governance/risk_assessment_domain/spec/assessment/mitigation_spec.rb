require "spec_helper"

RSpec.describe RiskAssessmentDomain::Assessment::Mitigation do
  subject(:mitigation) { described_class.new(
          finding_category: "example",
          action: "example",
          status: "example"
        ) }

  it "is immutable" do
    expect(mitigation).to be_frozen
  end

  it "is equal when all attributes match" do
    other = described_class.new(
          finding_category: "example",
          action: "example",
          status: "example"
        )
    expect(mitigation).to eq(other)
  end
end
