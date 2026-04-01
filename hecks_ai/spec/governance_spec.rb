require "spec_helper"
require "hecks_ai/governance_guard"
require "hecks_ai/governance_tools"

RSpec.describe Hecks::GovernanceGuard do
  describe "#check" do
    context "when no world goals are declared" do
      let(:domain) do
        ws = Hecks.workshop("Shop")
        ws.aggregate("Product") do
          attribute :name, String
          command("CreateProduct") { attribute :name, String }
        end
        ws.to_domain
      end

      it "allows all commands" do
        guard = described_class.new(domain)
        result = guard.check("CreateProduct")
        expect(result[:allowed]).to be true
        expect(result[:violations]).to be_empty
        expect(result[:goals]).to be_empty
      end
    end

    context "when transparency goal is declared and command emits no events" do
      let(:domain) do
        ws = Hecks.workshop("Clinic")
        ws.aggregate("Record") do
          attribute :title, String
          command("DeleteRecord") { attribute :id, String; emits [] }
        end
        ws.world_goals(:transparency)
        ws.to_domain
      end

      it "refuses the command with a transparency violation" do
        guard = described_class.new(domain)
        result = guard.check("DeleteRecord")
        expect(result[:allowed]).to be false
        expect(result[:violations].first).to include("Transparency")
        expect(result[:goals]).to eq([:transparency])
      end
    end

    context "when consent goal is declared and user-like aggregate has no actor" do
      let(:domain) do
        ws = Hecks.workshop("Health")
        ws.aggregate("Patient") do
          attribute :name, String
          command("UpdatePatient") { attribute :name, String }
        end
        ws.world_goals(:consent)
        ws.to_domain
      end

      it "refuses the command with a consent violation" do
        guard = described_class.new(domain)
        result = guard.check("UpdatePatient")
        expect(result[:allowed]).to be false
        expect(result[:violations].first).to include("Consent")
      end
    end

    context "when goals are met" do
      let(:domain) do
        ws = Hecks.workshop("Health")
        ws.aggregate("Patient") do
          attribute :name, String
          command("UpdatePatient") { attribute :name, String; actor "Doctor" }
        end
        ws.world_goals(:consent)
        ws.to_domain
      end

      it "allows the command" do
        guard = described_class.new(domain)
        result = guard.check("UpdatePatient")
        expect(result[:allowed]).to be true
        expect(result[:violations]).to be_empty
      end
    end
  end
end

RSpec.describe Hecks::MCP::GovernanceTools do
  describe "GOAL_DESCRIPTIONS" do
    it "has descriptions for all four built-in goals" do
      %i[transparency consent privacy security].each do |goal|
        expect(described_class::GOAL_DESCRIPTIONS).to have_key(goal)
      end
    end
  end
end
