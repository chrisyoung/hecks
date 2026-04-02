require "spec_helper"
require "hecks/runtime/extension_dispatch"

RSpec.describe Hecks::ExtensionDispatch do
  let(:domain) do
    Hecks.domain "DispatchTest" do
      aggregate "Gadget" do
        attribute :name, String

        command "CreateGadget" do
          attribute :name, String
        end
      end
    end
  end

  before do
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

  describe ".apply_hecksagon_concerns" do
    it "activates audit capability when hecksagon has :transparency concern" do
      Hecks.hecksagon do
        concerns :transparency
      end

      app = Hecks.load(domain)
      described_class.apply_hecksagon_concerns(app)

      DispatchTestDomain::Gadget.create(name: "Widget")
      expect(Hecks.audit_log.size).to eq(1)
      expect(Hecks.audit_log.first[:event_name]).to eq("CreatedGadget")
    end

    it "does nothing when hecksagon has no concerns" do
      Hecks.hecksagon do
        # no concerns declared
      end

      app = Hecks.load(domain)
      described_class.apply_hecksagon_concerns(app)

      expect(Hecks.respond_to?(:audit_log)).to be false
    end

    it "does nothing when no hecksagon is set" do
      Hecks.last_hecksagon = nil
      app = Hecks.load(domain)
      app.instance_variable_set(:@hecksagon, nil)

      expect { described_class.apply_hecksagon_concerns(app) }.not_to raise_error
    end
  end
end
