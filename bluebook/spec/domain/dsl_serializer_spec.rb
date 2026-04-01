require "spec_helper"

RSpec.describe Hecks::DslSerializer do
  it "serializes a domain back to DSL source" do
    domain = Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :style, String
        command "CreatePizza" do
          attribute :name, String
          attribute :style, String
        end
      end
    end

    source = described_class.new(domain).serialize
    expect(source).to include('Hecks.domain "Pizzas"')
    expect(source).to include('aggregate "Pizza"')
    expect(source).to include('attribute :name, String')
    expect(source).to include('command "CreatePizza"')
  end

  it "round-trips through eval" do
    domain = Hecks.domain "RoundTrip" do
      aggregate "Thing" do
        attribute :name, String
        command "CreateThing" do
          attribute :name, String
        end
      end
    end

    source = described_class.new(domain).serialize
    restored = eval(source)
    expect(restored.name).to eq("RoundTrip")
    expect(restored.aggregates.first.name).to eq("Thing")
  end

  it "emits version kwarg when domain has a version" do
    domain = Hecks.domain "Versioned", version: "2.1.0" do
      aggregate "Widget" do
        attribute :name, String
      end
    end

    source = described_class.new(domain).serialize
    expect(source).to include('Hecks.domain "Versioned", version: "2.1.0"')
  end

  it "omits version kwarg when domain has no version" do
    domain = Hecks.domain "Plain" do
      aggregate "Widget" do
        attribute :name, String
      end
    end

    source = described_class.new(domain).serialize
    expect(source).to include('Hecks.domain "Plain" do')
    expect(source).not_to include("version:")
  end
end
