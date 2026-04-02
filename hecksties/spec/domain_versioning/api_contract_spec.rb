# api_contract_spec.rb — HEC-100
#
# Specs for API contract serialization and diffing.
#
require "spec_helper"
require "json"
require "tmpdir"

RSpec.describe Hecks::DomainVersioning::ApiContract do
  let(:domain) do
    Hecks.domain "Test" do
      aggregate "Widget" do
        attribute :name, String
        attribute :color, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  describe ".serialize" do
    it "captures aggregate names and attributes" do
      contract = described_class.serialize(domain)
      expect(contract[:domain]).to eq("Test")
      agg = contract[:aggregates].first
      expect(agg[:name]).to eq("Widget")
      expect(agg[:attributes].map { |a| a[:name] }).to include("name", "color")
    end

    it "captures command signatures" do
      contract = described_class.serialize(domain)
      cmd = contract[:aggregates].first[:commands].first
      expect(cmd[:name]).to eq("CreateWidget")
      expect(cmd[:attributes].first[:name]).to eq("name")
    end
  end

  describe ".save and .load" do
    it "round-trips through JSON on disk" do
      Dir.mktmpdir do |dir|
        described_class.save(domain, base_dir: dir)
        loaded = described_class.load(base_dir: dir)
        expect(loaded[:domain]).to eq("Test")
        expect(loaded[:aggregates].first[:name]).to eq("Widget")
      end
    end

    it "returns nil when no contract file exists" do
      Dir.mktmpdir do |dir|
        expect(described_class.load(base_dir: dir)).to be_nil
      end
    end
  end

  describe ".diff" do
    let(:old_contract) { described_class.serialize(domain) }

    it "detects removed attributes as breaking" do
      new_domain = Hecks.domain("Test") do
        aggregate "Widget" do
          attribute :name, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
      new_contract = described_class.serialize(new_domain)
      changes = described_class.diff(old_contract, new_contract)
      kinds = changes.map(&:kind)
      expect(kinds).to include(:remove_attribute)
    end

    it "detects changed attribute types" do
      new_domain = Hecks.domain("Test") do
        aggregate "Widget" do
          attribute :name, Integer
          attribute :color, String
          command "CreateWidget" do
            attribute :name, String
          end
        end
      end
      new_contract = described_class.serialize(new_domain)
      changes = described_class.diff(old_contract, new_contract)
      type_change = changes.find { |c| c.kind == :change_attribute_type }
      expect(type_change).not_to be_nil
      expect(type_change.details[:old_type]).to eq("String")
      expect(type_change.details[:new_type]).to eq("Integer")
    end

    it "detects added required command attributes" do
      new_domain = Hecks.domain("Test") do
        aggregate "Widget" do
          attribute :name, String
          attribute :color, String
          command "CreateWidget" do
            attribute :name, String
            attribute :color, String
          end
        end
      end
      new_contract = described_class.serialize(new_domain)
      changes = described_class.diff(old_contract, new_contract)
      req = changes.find { |c| c.kind == :add_required_command_attribute }
      expect(req).not_to be_nil
      expect(req.details[:command]).to eq("CreateWidget")
      expect(req.details[:name]).to eq(:color)
    end

    it "detects removed aggregates" do
      new_domain = Hecks.domain("Test") do
        aggregate "Gadget" do
          attribute :label, String
          command "CreateGadget" do
            attribute :label, String
          end
        end
      end
      new_contract = described_class.serialize(new_domain)
      changes = described_class.diff(old_contract, new_contract)
      expect(changes.map(&:kind)).to include(:remove_aggregate)
    end

    it "returns empty when contracts match" do
      changes = described_class.diff(old_contract, old_contract)
      expect(changes).to be_empty
    end
  end
end
