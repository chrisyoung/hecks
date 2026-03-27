require "spec_helper"

RSpec.describe OperationsDomain::Incident::Commands::CloseIncident do
  describe "attributes" do
    subject(:command) { described_class.new(incident_id: "example") }

    it "has incident_id" do
      expect(command.incident_id).to eq("example")
    end

  end

  describe "event" do
    it "emits ClosedIncident" do
      expect(described_class.event_name).to eq("ClosedIncident")
    end
  end
end
