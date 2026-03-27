require "spec_helper"

RSpec.describe IdentityDomain::AuditLog::Commands::RecordEntry do
  describe "attributes" do
    subject(:command) { described_class.new(
          entity_type: "example",
          entity_id: "example",
          action: "example",
          actor_id: "example",
          details: "example"
        ) }

    it "has entity_type" do
      expect(command.entity_type).to eq("example")
    end

    it "has entity_id" do
      expect(command.entity_id).to eq("example")
    end

    it "has action" do
      expect(command.action).to eq("example")
    end

    it "has actor_id" do
      expect(command.actor_id).to eq("example")
    end

    it "has details" do
      expect(command.details).to eq("example")
    end

  end

  describe "event" do
    it "emits RecordedEntry" do
      expect(described_class.event_name).to eq("RecordedEntry")
    end
  end
end
