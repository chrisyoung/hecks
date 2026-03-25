require "spec_helper"
require "hecks_audit"

RSpec.describe "HecksAudit connection" do
  let(:domain) do
    Hecks.domain "AuditTest" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain)
    Hecks.extension_registry[:audit]&.call(
      Object.const_get("AuditTestDomain"), domain, @app
    )
  end

  after do
    Hecks.actor = nil
    Hecks.tenant = nil
  end

  it "records command after execution" do
    Widget.create(name: "Audit Test")
    mod = Object.const_get("AuditTestDomain")
    expect(mod.audit_log.size).to eq(1)
    expect(mod.audit_log.first[:command]).to eq("CreateWidget")
  end

  it "captures actor and tenant" do
    actor = Struct.new(:role).new("admin")
    Hecks.actor = actor
    Hecks.tenant = "acme"

    Widget.create(name: "Tenant Test")
    mod = Object.const_get("AuditTestDomain")
    entry = mod.audit_log.first
    expect(entry[:actor]).to eq("admin")
    expect(entry[:tenant]).to eq("acme")
  end

  it "is accessible via DomainMod.audit_log" do
    mod = Object.const_get("AuditTestDomain")
    expect(mod).to respond_to(:audit_log)
    expect(mod.audit_log).to be_an(Array)
  end
end
