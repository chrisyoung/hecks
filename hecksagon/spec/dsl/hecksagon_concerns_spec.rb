require "spec_helper"

RSpec.describe "Hecksagon concern expansion" do
  describe ":privacy concern" do
    it "expands to :pii and :encrypted extensions" do
      builder = Hecksagon::DSL::HecksagonBuilder.new("TestDomain")
      builder.concern(:privacy)
      hex = builder.build

      extension_names = hex.extensions.map { |e| e[:name] }
      expect(extension_names).to include(:pii)
      expect(extension_names).to include(:encrypted)
    end

    it "does not duplicate extensions on repeated concern calls" do
      builder = Hecksagon::DSL::HecksagonBuilder.new("TestDomain")
      builder.concern(:privacy)
      builder.concern(:privacy)
      hex = builder.build

      extension_names = hex.extensions.map { |e| e[:name] }
      expect(extension_names.count(:pii)).to eq(1)
      expect(extension_names.count(:encrypted)).to eq(1)
    end
  end

  describe "encrypted_attributes query" do
    it "returns encrypted field names from domain IR" do
      domain = Hecks.domain "EncAttrQuery" do
        aggregate "Secret" do
          attribute :label, String
          attribute :token, String, encrypted: true
          attribute :key, String, encrypted: true
        end
      end

      hex = Hecksagon::Structure::Hecksagon.new(name: "EncAttrQuery")
      names = hex.encrypted_attributes("Secret", domain: domain)
      expect(names).to eq([:token, :key])
    end

    it "returns empty array when no encrypted attributes" do
      domain = Hecks.domain "PlainQuery" do
        aggregate "Open" do
          attribute :label, String
        end
      end

      hex = Hecksagon::Structure::Hecksagon.new(name: "PlainQuery")
      expect(hex.encrypted_attributes("Open", domain: domain)).to eq([])
    end
  end
end
