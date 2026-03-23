require "spec_helper"

RSpec.describe Hecks::Migrations::DomainDiff do
  let(:old_domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        command "CreatePizza" do
          attribute :name, String
        end
      end
    end
  end

  describe "adding an attribute" do
    let(:new_domain) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String
          attribute :size, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end
    end

    it "detects the added attribute" do
      changes = described_class.call(old_domain, new_domain)
      added = changes.find { |c| c.kind == :add_attribute }
      expect(added).not_to be_nil
      expect(added.aggregate).to eq("Pizza")
      expect(added.details[:name]).to eq(:size)
    end
  end

  describe "removing an attribute" do
    let(:new_domain) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          command "CreatePizza" do
            attribute :name, String
          end
        end
      end
    end

    it "detects the removed attribute" do
      changes = described_class.call(old_domain, new_domain)
      removed = changes.find { |c| c.kind == :remove_attribute }
      expect(removed).not_to be_nil
      expect(removed.details[:name]).to eq(:name)
    end
  end

  describe "adding an aggregate" do
    let(:new_domain) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
        aggregate "Order" do
          attribute :quantity, Integer
          command "PlaceOrder" do
            attribute :quantity, Integer
          end
        end
      end
    end

    it "detects the new aggregate" do
      changes = described_class.call(old_domain, new_domain)
      added = changes.find { |c| c.kind == :add_aggregate }
      expect(added).not_to be_nil
      expect(added.aggregate).to eq("Order")
    end
  end

  describe "removing an aggregate" do
    let(:old_with_order) do
      Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end
        aggregate "Order" do
          attribute :quantity, Integer
          command "PlaceOrder" do
            attribute :quantity, Integer
          end
        end
      end
    end

    it "detects the removed aggregate" do
      changes = described_class.call(old_with_order, old_domain)
      removed = changes.find { |c| c.kind == :remove_aggregate }
      expect(removed).not_to be_nil
      expect(removed.aggregate).to eq("Order")
    end
  end

  describe "no changes" do
    it "returns empty array" do
      changes = described_class.call(old_domain, old_domain)
      expect(changes).to be_empty
    end
  end

  describe "from nil (first apply)" do
    it "treats everything as new" do
      changes = described_class.call(nil, old_domain)
      expect(changes.size).to eq(1)
      expect(changes.first.kind).to eq(:add_aggregate)
    end
  end
end
