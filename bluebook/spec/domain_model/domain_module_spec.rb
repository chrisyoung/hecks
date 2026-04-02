require "spec_helper"

RSpec.describe "Domain Modules — Namespace Grouping (HEC-78)" do
  let(:domain) do
    Hecks.domain "Governance" do
      domain_module "PolicyManagement" do
        aggregate "GovernancePolicy" do
          attribute :title, String
          command "CreateGovernancePolicy" do
            attribute :title, String
          end
        end
      end

      aggregate "AuditLog" do
        attribute :entry, String
        command "CreateAuditLog" do
          attribute :entry, String
        end
      end
    end
  end

  it "creates DomainModule IR nodes" do
    expect(domain.modules.size).to eq(1)
    mod = domain.modules.first
    expect(mod).to be_a(Hecks::DomainModel::Structure::DomainModule)
    expect(mod.name).to eq("PolicyManagement")
    expect(mod.aggregates).to eq(["GovernancePolicy"])
  end

  it "still registers aggregates on the domain" do
    expect(domain.aggregates.map(&:name)).to contain_exactly("GovernancePolicy", "AuditLog")
  end

  describe "#module_for" do
    it "finds the module containing an aggregate" do
      mod = domain.module_for("GovernancePolicy")
      expect(mod.name).to eq("PolicyManagement")
    end

    it "accepts an aggregate object" do
      agg = domain.aggregates.find { |a| a.name == "GovernancePolicy" }
      mod = domain.module_for(agg)
      expect(mod.name).to eq("PolicyManagement")
    end

    it "returns nil for ungrouped aggregates" do
      expect(domain.module_for("AuditLog")).to be_nil
    end
  end

  it "groups aggregates by module in the visualizer" do
    mermaid = domain.to_mermaid
    expect(mermaid).to include("namespace PolicyManagement")
  end

  it "serializes domain_module blocks in DSL round-trip" do
    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include('domain_module "PolicyManagement"')
    expect(source).to include('aggregate "GovernancePolicy"')
    # AuditLog should be outside the module block
    expect(source).to include('aggregate "AuditLog"')
  end
end
