require "spec_helper"

RSpec.describe RiskAssessmentDomain::Assessment::Commands::InitiateAssessment do
  describe "attributes" do
    subject(:command) { described_class.new(model_id: "example", assessor_id: "example") }

    it "has model_id" do
      expect(command.model_id).to eq("example")
    end

    it "has assessor_id" do
      expect(command.assessor_id).to eq("example")
    end

  end

  describe "event" do
    it "emits InitiatedAssessment" do
      expect(described_class.event_name).to eq("InitiatedAssessment")
    end
  end
end
