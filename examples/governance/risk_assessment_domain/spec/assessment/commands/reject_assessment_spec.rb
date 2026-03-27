require "spec_helper"

RSpec.describe RiskAssessmentDomain::Assessment::Commands::RejectAssessment do
  describe "attributes" do
    subject(:command) { described_class.new(assessment_id: "example") }

    it "has assessment_id" do
      expect(command.assessment_id).to eq("example")
    end

  end

  describe "event" do
    it "emits RejectedAssessment" do
      expect(described_class.event_name).to eq("RejectedAssessment")
    end
  end
end
