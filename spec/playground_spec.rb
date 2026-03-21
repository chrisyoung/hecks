require "spec_helper"

RSpec.describe Hecks::Playground do
  let(:domain) do
    Hecks.domain "Pizzas" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :toppings, list_of("Topping")

        value_object "Topping" do
          attribute :name, String
          attribute :amount, Integer
        end

        validation :name, presence: true

        command "CreatePizza" do
          attribute :name, String
        end

        command "AddTopping" do
          attribute :name, String
        end
      end

      aggregate "Order" do
        attribute :pizza_id, reference_to("Pizza")
        attribute :quantity, Integer

        command "PlaceOrder" do
          attribute :pizza_id, reference_to("Pizza")
          attribute :quantity, Integer
        end

        policy "ReserveIngredients" do
          on "PlacedOrder"
          trigger "ReserveStock"
        end
      end
    end
  end

  subject(:playground) { described_class.new(domain) }

  before { allow($stdout).to receive(:puts) }

  describe "#execute" do
    it "executes a command and returns an event" do
      event = playground.execute("CreatePizza", name: "Pepperoni")
      expect(event.name).to eq("Pepperoni")
      expect(event.occurred_at).to be_a(Time)
    end

    it "collects events" do
      playground.execute("CreatePizza", name: "Margherita")
      playground.execute("CreatePizza", name: "Pepperoni")
      expect(playground.events.size).to eq(2)
    end

    it "reports triggered policies" do
      output = []
      allow($stdout).to receive(:puts) { |msg| output << msg }

      playground.execute("PlaceOrder", pizza_id: "abc-123", quantity: 2)

      expect(output).to include("Command: PlaceOrder")
      expect(output).to include("  Policy: ReserveIngredients -> ReserveStock")
    end

    it "raises for unknown command" do
      expect { playground.execute("FlyToMoon") }.to raise_error(/Unknown command/)
    end
  end

  describe "#commands" do
    it "lists available commands with their signatures" do
      list = playground.commands
      expect(list).to include(/CreatePizza.*name.*CreatedPizza/)
      expect(list).to include(/PlaceOrder.*pizza_id.*PlacedOrder/)
    end
  end

  describe "#events_of" do
    it "filters events by type" do
      playground.execute("CreatePizza", name: "Margherita")
      playground.execute("AddTopping", name: "Cheese")

      created = playground.events_of("CreatedPizza")
      expect(created.size).to eq(1)
    end
  end

  describe "#reset!" do
    it "clears events" do
      playground.execute("CreatePizza", name: "Pepperoni")
      playground.reset!

      expect(playground.events).to be_empty
    end
  end

  describe "#history" do
    it "prints event timeline" do
      playground.execute("CreatePizza", name: "Margherita")
      expect { playground.history }.to output(/1\. CreatedPizza/).to_stdout
    end

    it "prints message when no events" do
      expect { playground.history }.to output(/No events yet/).to_stdout
    end
  end

  describe "#inspect" do
    it "shows summary" do
      playground.execute("CreatePizza", name: "Pepperoni")
      expect(playground.inspect).to match(/1 events/)
    end
  end
end
