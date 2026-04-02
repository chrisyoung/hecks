require "spec_helper"
require_relative "../lib/hecks/extensions/bubble"

RSpec.describe HecksBubble::Context do
  let(:context) do
    ctx = described_class.new
    ctx.map_aggregate :Pizza do
      from_legacy :pie_name, to: :name
      from_legacy :pie_desc, to: :description, transform: ->(v) { v.to_s.strip }
    end
    ctx
  end

  describe "#translate" do
    it "maps legacy fields to domain fields" do
      result = context.translate(:Pizza, :create, pie_name: "Margherita", pie_desc: "Classic")
      expect(result).to eq(name: "Margherita", description: "Classic")
    end

    it "applies transforms during forward mapping" do
      result = context.translate(:Pizza, :create, pie_name: "Pepperoni", pie_desc: "  Spicy  ")
      expect(result[:description]).to eq("Spicy")
    end

    it "passes through unmapped aggregates unchanged" do
      result = context.translate(:Order, :create, customer: "Alice")
      expect(result).to eq(customer: "Alice")
    end

    it "passes through unmapped fields unchanged" do
      result = context.translate(:Pizza, :create, pie_name: "Margherita", extra: "yes")
      expect(result).to eq(name: "Margherita", extra: "yes")
    end
  end

  describe "#reverse" do
    it "maps domain fields back to legacy fields" do
      result = context.reverse(:Pizza, name: "Margherita", description: "Classic")
      expect(result).to eq(pie_name: "Margherita", pie_desc: "Classic")
    end

    it "does not apply transforms in reverse" do
      result = context.reverse(:Pizza, name: "Pepperoni", description: "  Spicy  ")
      expect(result[:pie_desc]).to eq("  Spicy  ")
    end

    it "passes through unmapped aggregates unchanged" do
      result = context.reverse(:Order, customer: "Alice")
      expect(result).to eq(customer: "Alice")
    end
  end

  describe "#mapped_aggregates" do
    it "lists aggregates with mappings" do
      expect(context.mapped_aggregates).to eq([:Pizza])
    end
  end
end

RSpec.describe HecksBubble::AggregateMapping do
  let(:mapping) do
    m = described_class.new(:Pizza)
    m.from_legacy(:pie_name, to: :name)
    m.from_legacy(:pie_desc, to: :description, transform: ->(v) { v.upcase })
    m
  end

  describe "#forward" do
    it "renames and transforms fields" do
      result = mapping.forward(pie_name: "Margherita", pie_desc: "classic")
      expect(result).to eq(name: "Margherita", description: "CLASSIC")
    end
  end

  describe "#reverse" do
    it "renames fields without transforms" do
      result = mapping.reverse(name: "Margherita", description: "Classic")
      expect(result).to eq(pie_name: "Margherita", pie_desc: "Classic")
    end
  end
end
