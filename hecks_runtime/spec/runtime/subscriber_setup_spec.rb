require "spec_helper"

RSpec.describe "Subscriber setup" do
  let(:domain) do
    Hecks.domain "SubscriberTest" do
      aggregate "Pizza" do
        attribute :name, String

        command "CreatePizza" do
          attribute :name, String
        end

        on_event "CreatedPizza" do |event|
          $subscriber_log << "pizza: #{event.name}"
        end
      end

      aggregate "Order" do
        attribute :pizza, Integer

        command "PlaceOrder" do
          attribute :pizza, Integer
        end

        # Cross-aggregate: Order subscribes to Pizza's event
        on_event "CreatedPizza" do |event|
          $subscriber_log << "order: #{event.name}"
        end
      end
    end
  end

  before do
    $subscriber_log = []
  end

  after do
    $subscriber_log = nil
  end

  it "fires sync subscriber when event is published" do
    app = Hecks.load(domain, force: true)
    Pizza.create(name: "Margherita")
    expect($subscriber_log).to include("pizza: Margherita")
  end

  it "fires cross-aggregate subscriber" do
    app = Hecks.load(domain, force: true)
    Pizza.create(name: "Pepperoni")
    expect($subscriber_log).to include("order: Pepperoni")
  end

  it "fires multiple subscribers for the same event" do
    app = Hecks.load(domain, force: true)
    Pizza.create(name: "Hawaiian")
    pizza_entries = $subscriber_log.select { |l| l.include?("Hawaiian") }
    expect(pizza_entries.size).to eq(2)
  end

  it "does not fire subscriber for unrelated events" do
    app = Hecks.load(domain, force: true)
    seed = SubscriberTestDomain::Order.new(id: 42, pizza: 42, quantity: 1)
    seed.save
    Order.place(pizza: 42)
    pizza_subs = $subscriber_log.select { |l| l.start_with?("pizza:") }
    expect(pizza_subs).to be_empty
  end

  context "async subscriber" do
    let(:async_domain) do
      Hecks.domain "AsyncSubTest" do
        aggregate "Item" do
          attribute :name, String

          command "CreateItem" do
            attribute :name, String
          end

          on_event "CreatedItem", async: true do |event|
            $subscriber_log << "async: #{event.name}"
          end
        end
      end
    end

    it "calls async handler instead of inline" do
      async_calls = []
      app = Hecks.load(async_domain, force: true)
      app.async do |name, event|
        async_calls << { name: name, event: event }
      end

      Item.create(name: "Widget")
      expect(async_calls.size).to eq(1)
      expect(async_calls.first[:name]).to include("OnCreatedItem")
      expect($subscriber_log).to be_empty
    end

    it "falls back to inline when no async handler set" do
      app = Hecks.load(async_domain, force: true)
      Item.create(name: "Gadget")
      expect($subscriber_log).to include("async: Gadget")
    end
  end
end
