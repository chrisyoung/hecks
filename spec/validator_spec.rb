require "spec_helper"

RSpec.describe Hecks::Validator do
  describe "a valid domain" do
    let(:domain) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String

          command "CreatePizza" do
            attribute :name, String
          end
        end
      end
    end

    it "is valid" do
      validator = described_class.new(domain)
      expect(validator).to be_valid
    end
  end

  describe "duplicate aggregate names" do
    let(:domain) do
      Hecks::DomainModel::Domain.new(
        name: "Bad",
        aggregates: [
          Hecks::DomainModel::Aggregate.new(name: "Pizza"),
          Hecks::DomainModel::Aggregate.new(name: "Pizza")
        ]
      )
    end

    it "reports the error" do
      validator = described_class.new(domain)
      expect(validator).not_to be_valid
      expect(validator.errors).to include("Duplicate aggregate name: Pizza")
    end
  end

  describe "unknown reference" do
    let(:domain) do
      Hecks.domain "Bad" do
        aggregate "Order" do
          attribute :widget_id, reference_to("Widget")

          command "PlaceOrder" do
            attribute :widget_id, reference_to("Widget")
          end
        end
      end
    end

    it "reports the error" do
      validator = described_class.new(domain)
      expect(validator).not_to be_valid
      expect(validator.errors.first).to match(/unknown aggregate.*Widget/i)
    end
  end

  describe "policy referencing unknown event" do
    let(:domain) do
      Hecks.domain "Bad" do
        aggregate "Order" do
          attribute :name, String

          command "PlaceOrder" do
            attribute :name, String
          end

          policy "DoSomething" do
            on "NeverHappened"
            trigger "Something"
          end
        end
      end
    end

    it "reports the error" do
      validator = described_class.new(domain)
      expect(validator).not_to be_valid
      expect(validator.errors.first).to match(/unknown event.*NeverHappened/i)
    end
  end
end
