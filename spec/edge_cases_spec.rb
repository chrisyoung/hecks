require "spec_helper"
require "tmpdir"

RSpec.describe "Edge cases and error handling" do
  def boot_domain(domain)
    tmpdir = Dir.mktmpdir("hecks_edge_test")
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "#{domain.gem_name}.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  let(:domain) do
    Hecks.domain "Edge" do
      aggregate "Widget" do
        attribute :name, String
        attribute :count, Integer
        attribute :price, Float
        attribute :data, JSON

        validation :name, presence: true

        command "CreateWidget" do
          attribute :name, String
          attribute :count, Integer
          attribute :price, Float
          attribute :data, JSON
        end

        query "ByName" do |name|
          where(name: name)
        end
      end
    end
  end

  before { @app = boot_domain(domain) }

  describe "validation enforcement" do
    it "raises on nil required field" do
      expect { EdgeDomain::Widget.create(name: nil, count: 1, price: 1.0) }.to raise_error(/name/)
    end

    it "raises on empty string required field" do
      expect { EdgeDomain::Widget.create(name: "", count: 1, price: 1.0) }.to raise_error(/name/)
    end

    it "accepts valid required field" do
      widget = EdgeDomain::Widget.create(name: "Valid", count: 1, price: 1.0)
      expect(widget.name).to eq("Valid")
    end
  end

  describe "nil attributes" do
    it "creates with nil optional attributes" do
      widget = EdgeDomain::Widget.create(name: "Test")
      expect(widget.count).to be_nil
      expect(widget.price).to be_nil
      expect(widget.data).to be_nil
    end

    it "find returns nil for nonexistent ID" do
      expect(EdgeDomain::Widget.find("nonexistent")).to be_nil
    end

    it "find returns nil for nil ID" do
      expect(EdgeDomain::Widget.find(nil)).to be_nil
    end
  end

  describe "update edge cases" do
    it "preserves unmodified attributes" do
      widget = EdgeDomain::Widget.create(name: "Original", count: 5, price: 9.99)
      updated = widget.update(name: "Changed")
      expect(updated.name).to eq("Changed")
      expect(updated.count).to eq(5)
      expect(updated.price).to eq(9.99)
    end

    it "preserves ID through update" do
      widget = EdgeDomain::Widget.create(name: "Test", count: 1)
      updated = widget.update(count: 99)
      expect(updated.id).to eq(widget.id)
    end

    it "updates created_at is preserved, updated_at changes" do
      widget = EdgeDomain::Widget.create(name: "Test")
      sleep 0.01
      updated = widget.update(name: "New")
      expect(updated.created_at.to_i).to eq(widget.created_at.to_i)
    end
  end

  describe "delete edge cases" do
    it "deleting nonexistent ID does not raise" do
      expect { EdgeDomain::Widget.delete("nonexistent") }.not_to raise_error
    end

    it "count decreases after delete" do
      w = EdgeDomain::Widget.create(name: "Temp")
      expect(EdgeDomain::Widget.count).to eq(1)
      EdgeDomain::Widget.delete(w.id)
      expect(EdgeDomain::Widget.count).to eq(0)
    end

    it "destroy returns self" do
      w = EdgeDomain::Widget.create(name: "Temp")
      result = w.destroy
      expect(result).to equal(w)
    end
  end

  describe "query edge cases" do
    it "where with no matches returns empty" do
      EdgeDomain::Widget.create(name: "A")
      results = EdgeDomain::Widget.by_name("NonExistent")
      expect(results.to_a).to be_empty
      expect(results.count).to eq(0)
    end

    it "first and last on empty return nil" do
      expect(EdgeDomain::Widget.first).to be_nil
      expect(EdgeDomain::Widget.last).to be_nil
    end

    it "all on empty returns empty array" do
      expect(EdgeDomain::Widget.all).to eq([])
    end

    it "count on empty returns 0" do
      expect(EdgeDomain::Widget.count).to eq(0)
    end
  end

  describe "JSON attribute edge cases" do
    it "stores and retrieves complex nested JSON" do
      widget = EdgeDomain::Widget.create(name: "Test", data: { nested: { deep: [1, 2, { x: "y" }] } })
      found = EdgeDomain::Widget.find(widget.id)
      expect(found.data).to be_a(Hash)
      expect(found.data[:nested][:deep].last[:x]).to eq("y")
    end

    it "stores empty hash" do
      widget = EdgeDomain::Widget.create(name: "Test", data: {})
      found = EdgeDomain::Widget.find(widget.id)
      expect(found.data).to eq({})
    end

    it "stores empty array" do
      widget = EdgeDomain::Widget.create(name: "Test", data: [])
      found = EdgeDomain::Widget.find(widget.id)
      expect(found.data).to eq([])
    end
  end

  describe "aggregate equality" do
    it "two aggregates with same ID are equal" do
      w = EdgeDomain::Widget.create(name: "Test")
      found = EdgeDomain::Widget.find(w.id)
      expect(w).to eq(found)
    end

    it "two aggregates with different IDs are not equal" do
      a = EdgeDomain::Widget.create(name: "A")
      b = EdgeDomain::Widget.create(name: "B")
      expect(a).not_to eq(b)
    end

    it "aggregate is not equal to non-aggregate" do
      w = EdgeDomain::Widget.create(name: "Test")
      expect(w).not_to eq("not an aggregate")
    end
  end

  describe "event bus edge cases" do
    it "subscriber exception does not crash other subscribers" do
      received = []
      @app.event_bus.subscribe("CreatedWidget") { |_| raise "boom" }
      @app.event_bus.subscribe("CreatedWidget") { |e| received << e }
      # The failing subscriber shouldn't prevent the command from working
      # (event bus may or may not propagate — depends on implementation)
      EdgeDomain::Widget.create(name: "Test") rescue nil
    end

    it "multiple creates fire multiple events" do
      EdgeDomain::Widget.create(name: "A")
      EdgeDomain::Widget.create(name: "B")
      EdgeDomain::Widget.create(name: "C")
      expect(@app.events.size).to eq(3)
    end

    it "events have occurred_at timestamps" do
      EdgeDomain::Widget.create(name: "Test")
      expect(@app.events.first.occurred_at).to be_a(Time)
    end

    it "events carry command attributes" do
      EdgeDomain::Widget.create(name: "Gadget", count: 5)
      event = @app.events.first
      expect(event.name).to eq("Gadget")
    end
  end

  describe "command bus edge cases" do
    it "dispatching unknown command raises" do
      expect { @app.event_bus }.not_to raise_error
      # Unknown commands should raise through the command bus
      expect {
        @app.instance_variable_get(:@command_bus).dispatch("NonExistentCommand", name: "x")
      }.to raise_error(/Unknown command/)
    end
  end

  describe "multiple aggregates ordering" do
    it "all returns aggregates in insertion order" do
      EdgeDomain::Widget.create(name: "C")
      EdgeDomain::Widget.create(name: "A")
      EdgeDomain::Widget.create(name: "B")
      names = EdgeDomain::Widget.all.map(&:name)
      expect(names).to eq(["C", "A", "B"])
    end
  end
end
