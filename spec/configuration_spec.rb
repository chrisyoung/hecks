require "spec_helper"
require "tmpdir"

RSpec.describe Hecks::Configuration do
  def build_and_load(domain, tmpdir)
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    require domain.gem_name
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
  end

  describe "multi-domain with shared event bus" do
    it "events from one domain are visible to all apps" do
      domain_a = Hecks.domain("DomainA") { aggregate("Thing") { attribute :name, String; command("CreateThing") { attribute :name, String } } }
      domain_b = Hecks.domain("DomainB") { aggregate("Other") { attribute :name, String; command("CreateOther") { attribute :name, String } } }

      tmpdir = Dir.mktmpdir("hecks_config_test")
      build_and_load(domain_a, tmpdir)
      build_and_load(domain_b, tmpdir)

      shared_bus = Hecks::Services::EventBus.new
      app_a = Hecks::Services::Application.new(domain_a, event_bus: shared_bus)
      app_b = Hecks::Services::Application.new(domain_b, event_bus: shared_bus)

      DomainADomain::Thing.create(name: "test")

      expect(shared_bus.events.size).to eq(1)
      expect(shared_bus.events.first.class.name).to include("CreatedThing")
      expect(app_a.events.size).to eq(1)
      expect(app_b.events.size).to eq(1)
    end

    it "domains are isolated — can't access each other's classes" do
      domain_a = Hecks.domain("IsoA") { aggregate("Foo") { attribute :n, String; command("CreateFoo") { attribute :n, String } } }
      domain_b = Hecks.domain("IsoB") { aggregate("Bar") { attribute :n, String; command("CreateBar") { attribute :n, String } } }

      tmpdir = Dir.mktmpdir("hecks_iso_test")
      build_and_load(domain_a, tmpdir)
      build_and_load(domain_b, tmpdir)

      shared_bus = Hecks::Services::EventBus.new
      Hecks::Services::Application.new(domain_a, event_bus: shared_bus)
      Hecks::Services::Application.new(domain_b, event_bus: shared_bus)

      expect(defined?(IsoADomain::Bar)).to be_nil
      expect(defined?(IsoBDomain::Foo)).to be_nil
    end
  end

  describe "Application with external event_bus" do
    it "uses the provided event bus instead of creating one" do
      domain = Hecks.domain("Ext") { aggregate("W") { attribute :n, String; command("CreateW") { attribute :n, String } } }
      tmpdir = Dir.mktmpdir("hecks_ext_bus_test")
      build_and_load(domain, tmpdir)

      custom_bus = Hecks::Services::EventBus.new
      app = Hecks::Services::Application.new(domain, event_bus: custom_bus)

      expect(app.event_bus).to equal(custom_bus)

      ExtDomain::W.create(n: "test")
      expect(custom_bus.events.size).to eq(1)
    end
  end
end
