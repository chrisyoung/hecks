require "spec_helper"

RSpec.describe Hecks::Runtime::ConnectionSetup do
  let(:domain) { BootedDomains.pizzas }
  let(:mod_name) { domain.module_name + "Domain" }

  after do
    # Reset connections on the domain module to avoid cross-test leakage
    mod = Object.const_get(mod_name) rescue nil
    mod.instance_variable_set(:@connections, nil) if mod&.respond_to?(:connections)
  end

  describe "outbound event wiring" do
    it "forwards events to a callable handler" do
      received = []
      handler = ->(event) { received << event }

      BootedDomains.boot(domain)
      mod = Object.const_get(mod_name)
      mod.instance_variable_set(:@connections, nil)
      mod.extend(:audit, handler)

      Hecks.load(domain)

      Pizza.create(name: "Test", description: "extend :audit test")
      expect(received.size).to be >= 1
      event_names = received.map { |e| e.class.name.split("::").last }
      expect(event_names).to include("CreatedPizza")
    end
  end

  describe "cross-domain event wiring" do
    it "forwards events from a source domain's event bus" do
      BootedDomains.boot(domain)
      mod = Object.const_get(mod_name)
      mod.instance_variable_set(:@connections, nil)

      # Create a fake source domain module with an event bus
      source_bus = Hecks::EventBus.new
      source_mod = Module.new
      source_mod.extend(Hecks::DomainConnections)
      source_mod.instance_variable_set(:@event_bus, source_bus)

      mod.extend(source_mod)

      app = Hecks.load(domain)

      received = []
      app.on("FakeEvent") { |e| received << e }

      fake_event = double("Event", class: double(name: "Source::FakeEvent"))
      source_bus.publish(fake_event)

      expect(received).to include(fake_event)
    end
  end

  describe "event_bus exposure" do
    it "exposes event_bus on the domain module" do
      app = Hecks.load(domain)
      mod = Object.const_get(mod_name)
      expect(mod.event_bus).to eq(app.event_bus)
    end
  end
end
