require "spec_helper"

RSpec.describe "Bidirectional reference detection" do
  describe "Validator" do
    it "rejects bidirectional references" do
      domain = Hecks.domain "Bad" do
        aggregate "Pizza" do
          attribute :order_id, reference_to("Order")
          command "CreatePizza" do
            attribute :name, String
          end
        end

        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      expect(validator).not_to be_valid
      expect(validator.errors.first).to include("Bidirectional reference")
      expect(validator.errors.first).to include("Order")
      expect(validator.errors.first).to include("Pizza")
    end

    it "allows one-directional references" do
      domain = Hecks.domain "Good" do
        aggregate "Pizza" do
          attribute :name, String
          command "CreatePizza" do
            attribute :name, String
          end
        end

        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      expect(validator).to be_valid
    end

    it "reports only one error per bidirectional pair" do
      domain = Hecks.domain "Bad" do
        aggregate "Pizza" do
          attribute :order_id, reference_to("Order")
          command "CreatePizza" do
            attribute :name, String
          end
        end

        aggregate "Order" do
          attribute :pizza_id, reference_to("Pizza")
          command "PlaceOrder" do
            attribute :pizza_id, reference_to("Pizza")
          end
        end
      end

      validator = Hecks::Validator.new(domain)
      validator.valid?
      bidirectional_errors = validator.errors.select { |e| e.include?("Bidirectional") }
      expect(bidirectional_errors.size).to eq(1)
    end
  end

  describe "REPL warning" do
    before { allow($stdout).to receive(:puts) }

    it "warns immediately when adding a reference that creates a cycle" do
      session = Hecks::Workbench.new("Test")

      pizza = session.aggregate("Pizza")
      pizza.attr :name, String

      order = session.aggregate("Order")
      order.attr :pizza_id, order.reference_to("Pizza")

      # Now adding a back-reference from Pizza to Order should warn
      output = []
      allow($stdout).to receive(:puts) { |msg| output << msg }

      pizza.attr :order_id, pizza.reference_to("Order")

      warning = output.find { |msg| msg.to_s.include?("Bidirectional") }
      expect(warning).not_to be_nil
    end

    it "does not warn for one-directional references" do
      session = Hecks::Workbench.new("Test")

      session.aggregate("Pizza").attr :name, String

      output = []
      allow($stdout).to receive(:puts) { |msg| output << msg }

      order = session.aggregate("Order")
      order.attr :pizza_id, order.reference_to("Pizza")

      warning = output.find { |msg| msg.to_s.include?("Bidirectional") }
      expect(warning).to be_nil
    end
  end
end
