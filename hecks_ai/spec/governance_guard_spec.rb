require "spec_helper"

RSpec.describe Hecks::GovernanceGuard do
  describe "#check" do
    context "with no world concerns declared" do
      it "passes with empty result" do
        domain = Hecks.domain "Clean" do
          aggregate "Widget" do
            attribute :name, String
            command "CreateWidget" do
              attribute :name, String
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be true
        expect(result.violations).to be_empty
        expect(result.suggestions).to be_empty
      end
    end

    context "transparency concern" do
      it "flags commands that emit no events" do
        domain = Hecks.domain "Opaque" do
          world_concerns :transparency
          aggregate "Record" do
            attribute :name, String
            command "DeleteRecord" do
              attribute :id, String
              emits []
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be false
        expect(result.violations.size).to eq(1)
        expect(result.violations.first[:concern]).to eq(:transparency)
        expect(result.violations.first[:message]).to include("DeleteRecord")
      end

      it "passes when commands emit events normally" do
        domain = Hecks.domain "Transparent" do
          world_concerns :transparency
          aggregate "Record" do
            attribute :name, String
            command "CreateRecord" do
              attribute :name, String
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be true
      end
    end

    context "consent concern" do
      it "flags user-like aggregates with actor-less commands" do
        domain = Hecks.domain "NoConsent" do
          world_concerns :consent
          aggregate "Patient" do
            attribute :name, String
            command "UpdatePatient" do
              attribute :name, String
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be false
        expect(result.violations.first[:concern]).to eq(:consent)
        expect(result.violations.first[:message]).to include("Patient#UpdatePatient")
      end

      it "passes when user-like aggregate commands have actors" do
        domain = Hecks.domain "WithConsent" do
          world_concerns :consent
          aggregate "Patient" do
            attribute :name, String
            command "UpdatePatient" do
              attribute :name, String
              actor "Doctor"
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be true
      end
    end

    context "privacy concern" do
      it "flags visible PII attributes" do
        domain = Hecks.domain "LeakyPII" do
          world_concerns :privacy
          aggregate "Patient" do
            attribute :ssn, String, pii: true
            command "CreatePatient" do
              attribute :ssn, String
              actor "Admin"
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be false
        expect(result.violations.any? { |v| v[:concern] == :privacy && v[:message].include?("visible") }).to be true
      end

      it "flags PII-aggregate commands without actors" do
        domain = Hecks.domain "NoAudit" do
          world_concerns :privacy
          aggregate "Patient" do
            attribute :ssn, String, pii: true, visible: false
            command "CreatePatient" do
              attribute :ssn, String
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be false
        expect(result.violations.any? { |v| v[:message].include?("no actor") }).to be true
      end

      it "passes when PII is hidden and commands have actors" do
        domain = Hecks.domain "Secure" do
          world_concerns :privacy
          aggregate "Patient" do
            attribute :ssn, String, pii: true, visible: false
            command "CreatePatient" do
              attribute :ssn, String
              actor "Admin"
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be true
      end
    end

    context "security concern" do
      it "flags command actors not declared at domain level" do
        domain = Hecks.domain "Dangling" do
          world_concerns :security
          aggregate "Config" do
            attribute :key, String
            command "UpdateConfig" do
              attribute :key, String
              actor "Ghost"
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be false
        expect(result.violations.first[:concern]).to eq(:security)
        expect(result.violations.first[:message]).to include("Ghost")
      end

      it "passes when command actors match domain actors" do
        domain = Hecks.domain "Locked" do
          world_concerns :security
          actor "Admin"
          aggregate "Config" do
            attribute :key, String
            command "UpdateConfig" do
              attribute :key, String
              actor "Admin"
            end
          end
        end

        result = described_class.new(domain).check
        expect(result.passed?).to be true
      end
    end

    context "multiple concerns" do
      it "collects violations from all declared concerns" do
        domain = Hecks.domain "MultiConcern" do
          world_concerns :transparency, :consent
          aggregate "Patient" do
            attribute :name, String
            command "DeletePatient" do
              attribute :id, String
              emits []
            end
          end
        end

        result = described_class.new(domain).check
        concerns = result.violations.map { |v| v[:concern] }.uniq
        expect(concerns).to include(:transparency)
        expect(concerns).to include(:consent)
      end
    end

    context "without API key (rule-based fallback)" do
      it "works without ANTHROPIC_API_KEY" do
        domain = Hecks.domain "NoKey" do
          world_concerns :transparency
          aggregate "Record" do
            attribute :name, String
            command "DeleteRecord" do
              attribute :id, String
              emits []
            end
          end
        end

        result = described_class.new(domain, api_key: nil).check
        expect(result.passed?).to be false
        expect(result.suggestions).not_to be_empty
      end
    end

    describe "Result#to_h" do
      it "returns a structured hash" do
        result = Hecks::GovernanceGuard::Result.new(
          violations: [{ concern: :privacy, message: "PII exposed" }],
          suggestions: ["Fix it"]
        )

        hash = result.to_h
        expect(hash[:passed]).to be false
        expect(hash[:violations].size).to eq(1)
        expect(hash[:suggestions]).to eq(["Fix it"])
      end
    end
  end
end
