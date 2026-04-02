require "spec_helper"

RSpec.describe Hecks::DomainModel::Structure::DomainModule do
  subject(:mod) do
    described_class.new(name: "Fulfillment", aggregate_names: ["Order", "Shipment"])
  end

  it "stores the module name" do
    expect(mod.name).to eq("Fulfillment")
  end

  it "stores aggregate names" do
    expect(mod.aggregate_names).to eq(["Order", "Shipment"])
  end

  it "defaults aggregate_names to empty array" do
    m = described_class.new(name: "Empty")
    expect(m.aggregate_names).to eq([])
  end
end

RSpec.describe "Domain#module_for" do
  let(:domain) do
    Hecks.domain "ECommerce" do
      domain_module "Catalog" do
        aggregate("Product") { attribute :name, String; command("CreateProduct") { attribute :name, String } }
      end

      domain_module "Fulfillment" do
        aggregate("Order") { attribute :qty, Integer; command("PlaceOrder") { attribute :qty, Integer } }
        aggregate("Shipment") { attribute :tracking, String; command("CreateShipment") { attribute :tracking, String } }
      end

      aggregate("Review") { attribute :body, String; command("CreateReview") { attribute :body, String } }
    end
  end

  it "returns the module containing the aggregate" do
    mod = domain.module_for("Product")
    expect(mod).not_to be_nil
    expect(mod.name).to eq("Catalog")
  end

  it "finds aggregates in multi-aggregate modules" do
    expect(domain.module_for("Order").name).to eq("Fulfillment")
    expect(domain.module_for("Shipment").name).to eq("Fulfillment")
  end

  it "returns nil for ungrouped aggregates" do
    expect(domain.module_for("Review")).to be_nil
  end

  it "returns nil for unknown aggregates" do
    expect(domain.module_for("NonExistent")).to be_nil
  end

  it "stores modules as DomainModule IR nodes" do
    domain.modules.each do |m|
      expect(m).to be_a(Hecks::DomainModel::Structure::DomainModule)
    end
  end

  it "all aggregates are flat on the domain regardless of module" do
    expect(domain.aggregates.map(&:name)).to contain_exactly("Product", "Order", "Shipment", "Review")
  end
end

RSpec.describe "Visualizer with domain_modules" do
  let(:domain) do
    Hecks.domain "Shop" do
      domain_module "Catalog" do
        aggregate("Product") do
          attribute :name, String
          command("CreateProduct") { attribute :name, String }
        end
      end

      domain_module "Sales" do
        aggregate("Order") do
          attribute :qty, Integer
          reference_to "Product"
          command("PlaceOrder") { attribute :qty, Integer }
        end
      end

      aggregate("Review") do
        attribute :body, String
        command("CreateReview") { attribute :body, String }
      end
    end
  end

  let(:mermaid) { Hecks::DomainVisualizer.new(domain).generate }

  describe "structure diagram" do
    it "wraps module aggregates in namespace blocks" do
      expect(mermaid).to include("namespace Catalog {")
      expect(mermaid).to include("namespace Sales {")
    end

    it "renders ungrouped aggregates outside namespaces" do
      expect(mermaid).to include("class Review {")
    end

    it "still shows cross-module references" do
      expect(mermaid).to include("Order --> Product : product")
    end
  end

  describe "behavior diagram" do
    it "wraps module aggregates in module subgraphs" do
      expect(mermaid).to include("subgraph Catalog")
      expect(mermaid).to include("subgraph Sales")
    end

    it "nests aggregate subgraphs inside module subgraphs" do
      expect(mermaid).to include("subgraph Product")
      expect(mermaid).to include("subgraph Order")
    end

    it "renders ungrouped aggregate subgraphs at top level" do
      expect(mermaid).to include("subgraph Review")
    end
  end
end

RSpec.describe "DslSerializer with domain_modules" do
  let(:domain) do
    Hecks.domain "Shop" do
      domain_module "Catalog" do
        aggregate("Product") { attribute :name, String; command("CreateProduct") { attribute :name, String } }
      end

      aggregate("Review") { attribute :body, String; command("CreateReview") { attribute :body, String } }
    end
  end

  let(:source) { Hecks::DslSerializer.new(domain).serialize }

  it "emits domain_module blocks" do
    expect(source).to include('domain_module "Catalog" do')
  end

  it "nests aggregates inside module blocks" do
    expect(source).to include('domain_module "Catalog" do')
    expect(source).to include('aggregate "Product" do')
  end

  it "emits ungrouped aggregates outside module blocks" do
    expect(source).to include('aggregate "Review" do')
  end

  it "round-trips through eval" do
    restored = eval(source)
    expect(restored.modules.size).to eq(1)
    expect(restored.modules.first.name).to eq("Catalog")
    expect(restored.modules.first.aggregate_names).to eq(["Product"])
    expect(restored.aggregates.map(&:name)).to contain_exactly("Product", "Review")
  end
end
