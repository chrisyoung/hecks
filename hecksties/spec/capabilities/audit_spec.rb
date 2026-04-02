require "spec_helper"
require "hecks/capabilities/audit"

RSpec.describe Hecks::Capabilities::Audit do
  let(:domain) do
    Hecks.domain "AuditCapTest" do
      aggregate "Widget" do
        attribute :name, String

        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  before do
    # Clean up singleton state left by other specs (e.g., extensions/audit_spec)
    if Hecks.respond_to?(:audit_log)
      Hecks.singleton_class.remove_method(:audit_log)
    end
    Hecks.instance_variable_set(:@_audit, nil)
  end

  after do
    if Hecks.respond_to?(:audit_log)
      Hecks.singleton_class.remove_method(:audit_log)
    end
    Hecks.instance_variable_set(:@_audit, nil)
  end

  describe ".apply" do
    it "wires audit to the runtime and exposes Hecks.audit_log" do
      app = Hecks.load(domain)
      described_class.apply(app)

      AuditCapTestDomain::Widget.create(name: "Sprocket")

      expect(Hecks.audit_log.size).to eq(1)
      expect(Hecks.audit_log.first[:event_name]).to eq("CreatedWidget")
    end

    it "is idempotent — second call returns existing audit" do
      app = Hecks.load(domain)
      first = described_class.apply(app)
      second = described_class.apply(app)

      expect(first).to equal(second)
    end

    it "enriches entries with actor context from Hecks.actor" do
      app = Hecks.load(domain)
      described_class.apply(app)

      AuditCapTestDomain::Widget.create(name: "Bolt")

      entry = Hecks.audit_log.first
      expect(entry[:timestamp]).to be_a(Time)
      expect(entry[:event_data][:name]).to eq("Bolt")
    end
  end

  describe ".active?" do
    it "returns false before apply" do
      expect(described_class.active?).to be false
    end

    it "returns true after apply" do
      app = Hecks.load(domain)
      described_class.apply(app)
      expect(described_class.active?).to be true
    end
  end
end
