require "spec_helper"

RSpec.describe OperationsDomain::Incident::Commands::InvestigateIncident do
  describe "attributes" do
    subject(:command) { described_class.new(incident_id: "example") }

    it "has incident_id" do
      expect(command.incident_id).to eq("example")
    end

  end

  describe "event" do
    it "emits InvestigatedIncident" do
      expect(described_class.event_name).to eq("InvestigatedIncident")
    end
  end
end
