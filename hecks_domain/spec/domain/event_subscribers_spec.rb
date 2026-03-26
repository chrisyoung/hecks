require "spec_helper"

RSpec.describe "Domain-level on_event subscribers" do
  describe "DSL: on_event at domain level" do
    it "collects event subscribers in DomainBuilder" do
      received = nil

      domain = Hecks.domain "Governance" do
        aggregate "AiModel" do
          attribute :name, String

          command "RegisterModel" do
            attribute :name, String
          end
        end

        on_event "RegisteredModel" do |event|
          received = event
        end
      end

      expect(domain.event_subscribers.size).to eq(1)
      expect(domain.event_subscribers.first[:event_name]).to eq("RegisteredModel")
    end
  end

  describe "IR: Domain stores event_subscribers" do
    it "defaults to empty array" do
      domain = Hecks::DomainModel::Structure::Domain.new(name: "Empty")
      expect(domain.event_subscribers).to eq([])
    end

    it "stores provided event subscribers" do
      sub = { event_name: "SomeEvent", block: proc {} }
      domain = Hecks::DomainModel::Structure::Domain.new(
        name: "Test", event_subscribers: [sub]
      )
      expect(domain.event_subscribers.size).to eq(1)
    end
  end

  describe "Runtime: domain-level subscribers fire on events" do
    it "calls the subscriber block when the event is published" do
      received_events = []

      domain = Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String

          command "CreatePizza" do
            attribute :name, String
          end
        end

        on_event "CreatedPizza" do |event|
          received_events << event
        end
      end

      Hecks.load(domain)
      PizzasDomain::Pizza.create(name: "Margherita")

      expect(received_events.size).to eq(1)
      expect(received_events.first.name).to eq("Margherita")
    end

    it "supports multiple domain-level subscribers" do
      log_a = []
      log_b = []

      domain = Hecks.domain "Pizzas" do
        aggregate "Pizza" do
          attribute :name, String

          command "CreatePizza" do
            attribute :name, String
          end
        end

        on_event "CreatedPizza" do |event|
          log_a << event.name
        end

        on_event "CreatedPizza" do |event|
          log_b << "got:#{event.name}"
        end
      end

      Hecks.load(domain)
      PizzasDomain::Pizza.create(name: "Pepperoni")

      expect(log_a).to eq(["Pepperoni"])
      expect(log_b).to eq(["got:Pepperoni"])
    end
  end
end
