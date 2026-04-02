require "spec_helper"

RSpec.describe "Event versioning and upcasting" do
  describe "schema_version on DomainEvent IR" do
    it "defaults to 1" do
      domain = Hecks.domain "VersionDefault" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end

      event = domain.aggregates.first.events.first
      expect(event.schema_version).to eq(1)
    end

    it "accepts an explicit schema_version on an event" do
      domain = Hecks.domain "VersionExplicit" do
        aggregate "Widget" do
          attribute :name, String

          event "WidgetArchived" do
            schema_version 3
            attribute :widget_id, String
          end
        end
      end

      event = domain.aggregates.first.events.find { |e| e.name == "WidgetArchived" }
      expect(event.schema_version).to eq(3)
    end
  end

  describe "upcast DSL at domain level" do
    it "stores upcaster declarations on the domain IR" do
      domain = Hecks.domain "UpcastDSL" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end

        upcast "CreatedWidget", from: 1, to: 2 do |data|
          data.merge("color" => "default")
        end
      end

      expect(domain.upcasters.size).to eq(1)
      decl = domain.upcasters.first
      expect(decl.event_type).to eq("CreatedWidget")
      expect(decl.from).to eq(1)
      expect(decl.to).to eq(2)
      expect(decl.transform).to be_a(Proc)
    end
  end

  describe Hecks::Events::UpcasterRegistry do
    subject(:registry) { described_class.new }

    it "registers and looks up transforms" do
      registry.register("CreatedWidget", from: 1, to: 2) { |d| d.merge("v2" => true) }

      entry = registry.lookup("CreatedWidget", 1)
      expect(entry[:to]).to eq(2)
      expect(entry[:transform].call({})).to eq({ "v2" => true })
    end

    it "returns nil for missing transforms" do
      expect(registry.lookup("CreatedWidget", 99)).to be_nil
    end

    it "reports any_for?" do
      registry.register("CreatedWidget", from: 1, to: 2) { |d| d }
      expect(registry.any_for?("CreatedWidget")).to be true
      expect(registry.any_for?("Unknown")).to be false
    end
  end

  describe Hecks::Events::UpcasterEngine do
    let(:registry) { Hecks::Events::UpcasterRegistry.new }
    subject(:engine) { described_class.new(registry) }

    before do
      registry.register("CreatedWidget", from: 1, to: 2) do |data|
        data.merge("color" => "default")
      end
      registry.register("CreatedWidget", from: 2, to: 3) do |data|
        data.merge("size" => "medium")
      end
    end

    it "chains transforms from v1 to v3" do
      result = engine.upcast("CreatedWidget",
        data: { "name" => "W" }, from_version: 1, to_version: 3)
      expect(result).to eq({ "name" => "W", "color" => "default", "size" => "medium" })
    end

    it "applies a single step from v2 to v3" do
      result = engine.upcast("CreatedWidget",
        data: { "name" => "W", "color" => "blue" }, from_version: 2, to_version: 3)
      expect(result).to eq({ "name" => "W", "color" => "blue", "size" => "medium" })
    end

    it "returns data unchanged when already at target version" do
      data = { "name" => "W" }
      result = engine.upcast("CreatedWidget", data: data, from_version: 3, to_version: 3)
      expect(result).to eq(data)
    end

    it "raises when a transform is missing" do
      expect {
        engine.upcast("CreatedWidget", data: {}, from_version: 5, to_version: 6)
      }.to raise_error(Hecks::Error, /Missing upcaster/)
    end
  end

  describe Hecks::Events::BuildEngine do
    it "builds an engine from domain upcaster declarations" do
      domain = Hecks.domain "BuildEngineTest" do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end

        upcast "CreatedWidget", from: 1, to: 2 do |data|
          data.merge("added" => true)
        end
      end

      engine = Hecks::Events::BuildEngine.call(domain)
      result = engine.upcast("CreatedWidget",
        data: { "name" => "W" }, from_version: 1, to_version: 2)
      expect(result).to eq({ "name" => "W", "added" => true })
    end
  end
end
