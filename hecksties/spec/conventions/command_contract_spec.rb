require "spec_helper"

RSpec.describe Hecks::Conventions::CommandContract do
  describe ".method_name" do
    it { expect(described_class.method_name("CreatePolicy", "GovernancePolicy")).to eq(:create) }
    it { expect(described_class.method_name("ActivatePolicy", "GovernancePolicy")).to eq(:activate) }
    it { expect(described_class.method_name("SuspendPolicy", "GovernancePolicy")).to eq(:suspend) }
    it { expect(described_class.method_name("CreatePizza", "Pizza")).to eq(:create) }
    it { expect(described_class.method_name("UpdatePizza", "Pizza")).to eq(:update) }
  end

  describe ".agg_suffixes" do
    it { expect(described_class.agg_suffixes("GovernancePolicy")).to eq(["governance_policy", "policy"]) }
    it { expect(described_class.agg_suffixes("Pizza")).to eq(["pizza"]) }
    it { expect(described_class.agg_suffixes("governance_policy")).to eq(["governance_policy", "policy"]) }
  end

  describe ".reference_attribute?" do
    it { expect(described_class.reference_attribute?("policy_id", "GovernancePolicy")).to be true }
    it { expect(described_class.reference_attribute?("governance_policy_id", "GovernancePolicy")).to be true }
    it { expect(described_class.reference_attribute?("pizza_id", "Pizza")).to be true }
    it { expect(described_class.reference_attribute?("name", "Pizza")).to be false }
    it { expect(described_class.reference_attribute?("order_id", "Pizza")).to be false }
  end

  describe ".find_self_ref" do
    it "returns the self-referencing attribute" do
      domain = Hecks.domain "Test" do
        aggregate "GovernancePolicy" do
          attribute :name, String
          command "ActivatePolicy" do
            attribute :policy_id, String
          end
        end
      end
      cmd = domain.aggregates.first.commands.first
      ref = described_class.find_self_ref(cmd, "GovernancePolicy")
      expect(ref.name.to_s).to eq("policy_id")
    end

    it "returns nil for create commands" do
      domain = Hecks.domain "Test" do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end
      cmd = domain.aggregates.first.commands.first
      expect(described_class.find_self_ref(cmd, "Pizza")).to be_nil
    end
  end
end
