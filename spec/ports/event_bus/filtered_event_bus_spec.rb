require "spec_helper"

RSpec.describe Hecks::FilteredEventBus do
  let(:inner) { Hecks::EventBus.new }

  def make_event(name, source: nil)
    klass = Class.new { define_method(:class) { Class.new { define_method(:name) { name } }.new } }
    event = klass.new
    event.instance_variable_set(:@_source_domain, source) if source
    event
  end

  describe "with no source filter (open mode)" do
    let(:bus) { described_class.new(inner: inner, domain_gem_name: "a_domain") }

    it "passes all events through" do
      received = []
      bus.subscribe("Foo") { |e| received << e }
      event = make_event("Foo")
      bus.publish(event)
      expect(received.size).to eq(1)
    end

    it "tags published events with source domain" do
      event = make_event("Foo")
      bus.publish(event)
      expect(event.instance_variable_get(:@_source_domain)).to eq("a_domain")
    end
  end

  describe "with allowed_sources filter" do
    let(:bus) do
      described_class.new(
        inner: inner,
        domain_gem_name: "listener_domain",
        allowed_sources: ["allowed_domain"]
      )
    end

    it "passes events from allowed sources" do
      received = []
      bus.subscribe("Foo") { |e| received << e }
      event = make_event("Foo")
      event.instance_variable_set(:@_source_domain, "allowed_domain")
      inner.publish(event)
      expect(received.size).to eq(1)
    end

    it "blocks events from disallowed sources" do
      received = []
      bus.subscribe("Foo") { |e| received << e }
      event = make_event("Foo")
      event.instance_variable_set(:@_source_domain, "other_domain")
      inner.publish(event)
      expect(received).to be_empty
    end

    it "passes events with no source tag (backward compat)" do
      received = []
      bus.subscribe("Foo") { |e| received << e }
      inner.publish(make_event("Foo"))
      expect(received.size).to eq(1)
    end
  end

  describe "#on_any" do
    let(:bus) do
      described_class.new(
        inner: inner,
        domain_gem_name: "listener_domain",
        allowed_sources: ["ok_domain"]
      )
    end

    it "filters on_any handlers by source" do
      received = []
      bus.on_any { |e| received << e }

      ok = make_event("A")
      ok.instance_variable_set(:@_source_domain, "ok_domain")
      inner.publish(ok)

      blocked = make_event("B")
      blocked.instance_variable_set(:@_source_domain, "bad_domain")
      inner.publish(blocked)

      expect(received.size).to eq(1)
    end
  end
end
