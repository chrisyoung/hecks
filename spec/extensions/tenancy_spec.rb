require "spec_helper"
require "hecks/extensions/tenancy"

RSpec.describe "HecksTenancy" do
  let(:domain) do
    Hecks.domain "TenantTest" do
      tenancy :column
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
    # Manually trigger tenancy connection hook
    Hecks.extension_registry[:tenancy]&.call(
      Object.const_get("TenantTestDomain"), domain, @app
    )
  end

  after { Hecks.tenant = nil }

  describe "DSL" do
    it "stores tenancy strategy on domain" do
      expect(domain.tenancy).to eq(:column)
    end

    it "defaults to nil when not declared" do
      d = Hecks.domain("NoTenant") { aggregate("Foo") { attribute :name, String; command("CreateFoo") { attribute :name, String } } }
      expect(d.tenancy).to be_nil
    end
  end

  describe "tenant isolation" do
    it "isolates data between tenants" do
      Hecks.tenant = "acme"
      Widget.create(name: "Rocket")

      Hecks.tenant = "beta"
      expect(Widget.all).to be_empty
      expect(Widget.count).to eq(0)
    end

    it "each tenant sees only their data" do
      Hecks.tenant = "acme"
      Widget.create(name: "Rocket")

      Hecks.tenant = "beta"
      Widget.create(name: "Submarine")

      Hecks.tenant = "acme"
      expect(Widget.count).to eq(1)
      expect(Widget.all.first.name).to eq("Rocket")

      Hecks.tenant = "beta"
      expect(Widget.count).to eq(1)
      expect(Widget.all.first.name).to eq("Submarine")
    end
  end

  describe "default tenant" do
    it "works without setting a tenant" do
      Widget.create(name: "Default")
      expect(Widget.count).to eq(1)
    end
  end

  describe "Hecks.with_tenant" do
    it "scopes operations to the given tenant" do
      Hecks.with_tenant("acme") { Widget.create(name: "Scoped") }
      Hecks.with_tenant("beta") { expect(Widget.all).to be_empty }
      Hecks.with_tenant("acme") { expect(Widget.count).to eq(1) }
    end

    it "restores previous tenant after block" do
      Hecks.tenant = "outer"
      Hecks.with_tenant("inner") { expect(Hecks.tenant).to eq("inner") }
      expect(Hecks.tenant).to eq("outer")
    end
  end
end
