require "spec_helper"
require "hecks_deprecations"

RSpec.describe HecksDeprecations do
  it "tracks all registered deprecations" do
    expect(HecksDeprecations.registered).to be_an(Array)
    expect(HecksDeprecations.registered.size).to be >= 6
  end

  describe "CommandStep" do
    let(:step) { Hecks::DomainModel::Behavior::CommandStep.new(command: "ScoreLoan", mapping: { score: :principal }) }

    it "supports deprecated [] access with warning" do
      expect { step[:command] }.to output(/DEPRECATION/).to_stderr
      expect(step[:command]).to eq("ScoreLoan")
      expect(step[:mapping]).to eq({ score: :principal })
    end

    it "supports deprecated to_h with warning" do
      expect { step.to_h }.to output(/DEPRECATION/).to_stderr
      expect(step.to_h).to eq({ command: "ScoreLoan", mapping: { score: :principal } })
    end
  end

  describe "BranchStep" do
    let(:branch) { Hecks::DomainModel::Behavior::BranchStep.new(spec: "HighRisk", if_steps: [:a], else_steps: [:b]) }

    it "supports deprecated [] access with warning" do
      expect { branch[:spec] }.to output(/DEPRECATION/).to_stderr
      expect(branch[:spec]).to eq("HighRisk")
      expect(branch[:if_steps]).to eq([:a])
      expect(branch[:else_steps]).to eq([:b])
    end
  end

  describe "ScheduledStep" do
    let(:step) { Hecks::DomainModel::Behavior::ScheduledStep.new(name: "cleanup", find_aggregate: "License", trigger: "Revoke") }

    it "supports deprecated [] access with warning" do
      expect { step[:name] }.to output(/DEPRECATION/).to_stderr
      expect(step[:name]).to eq("cleanup")
      expect(step[:trigger]).to eq("Revoke")
    end
  end

  describe "PersistConfig" do
    it "supports deprecated == Hash comparison with warning" do
      config = Hecks::PersistConfig.new(type: :sqlite)
      expect { config == { type: :sqlite } }.to output(/DEPRECATION/).to_stderr
      expect(config == { type: :sqlite }).to be true
    end
  end

  describe "SendConfig" do
    it "supports deprecated [] access with warning" do
      config = Hecks::SendConfig.new(name: :audit, handler: nil, webhook: "http://x")
      expect { config[:name] }.to output(/DEPRECATION/).to_stderr
      expect(config[:name]).to eq(:audit)
      expect(config[:webhook]).to eq("http://x")
    end
  end

  describe "ExtensionConfig" do
    it "supports deprecated == Hash comparison with warning" do
      config = Hecks::ExtensionConfig.new(name: :tenancy)
      expect { config == { name: :tenancy } }.to output(/DEPRECATION/).to_stderr
      expect(config == { name: :tenancy }).to be true
    end
  end
end
