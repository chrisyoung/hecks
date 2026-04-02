require "spec_helper"

RSpec.describe "Domain Classification (HEC-76)" do
  it "defaults to :supporting when unset" do
    domain = Hecks.domain "Basic" do
      aggregate "Thing" do
        attribute :name, String
        command "CreateThing" do
          attribute :name, String
        end
      end
    end

    expect(domain.domain_classification).to eq(:supporting)
    expect(domain).to be_supporting
    expect(domain).not_to be_core
    expect(domain).not_to be_generic
  end

  it "accepts :core classification" do
    domain = Hecks.domain "Core" do
      classification :core

      aggregate "Thing" do
        attribute :name, String
        command "CreateThing" do
          attribute :name, String
        end
      end
    end

    expect(domain.domain_classification).to eq(:core)
    expect(domain).to be_core
    expect(domain).not_to be_supporting
  end

  it "accepts :generic classification" do
    domain = Hecks.domain "Generic" do
      classification :generic

      aggregate "Thing" do
        attribute :name, String
        command "CreateThing" do
          attribute :name, String
        end
      end
    end

    expect(domain.domain_classification).to eq(:generic)
    expect(domain).to be_generic
  end

  it "rejects invalid classifications" do
    expect {
      Hecks.domain "Bad" do
        classification :invalid
      end
    }.to raise_error(ArgumentError, /must be one of/)
  end

  it "serializes non-default classification in DSL round-trip" do
    domain = Hecks.domain "Payments" do
      classification :core

      aggregate "Payment" do
        attribute :amount, Integer
        command "CreatePayment" do
          attribute :amount, Integer
        end
      end
    end

    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include("classification :core")
  end

  it "omits :supporting from serialization (it is the default)" do
    domain = Hecks.domain "Reports" do
      aggregate "Report" do
        attribute :name, String
        command "CreateReport" do
          attribute :name, String
        end
      end
    end

    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).not_to include("classification")
  end
end
