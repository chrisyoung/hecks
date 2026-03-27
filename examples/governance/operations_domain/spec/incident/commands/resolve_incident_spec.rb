require "spec_helper"

RSpec.describe OperationsDomain::Incident::Commands::ResolveIncident do
  describe "attributes" do
    subject(:command) { described_class.new(
          incident_id: "example",
          resolution: "example",
          root_cause: "example"
        ) }

    it "has incident_id" do
      expect(command.incident_id).to eq("example")
    end

    it "has resolution" do
      expect(command.resolution).to eq("example")
    end

    it "has root_cause" do
      expect(command.root_cause).to eq("example")
    end

  end

  describe "event" do
    it "emits ResolvedIncident" do
      expect(described_class.event_name).to eq("ResolvedIncident")
    end
  end
end
