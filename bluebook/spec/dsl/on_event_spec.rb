require "spec_helper"

RSpec.describe "on_event DSL" do
  it "creates an EventSubscriber on the aggregate" do
    domain = Hecks.domain "SubDsl" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end

        on_event "CreatedWidget" do |event|
          puts event.name
        end
      end
    end

    agg = domain.aggregates.first
    expect(agg.subscribers.size).to eq(1)

    sub = agg.subscribers.first
    expect(sub.name).to eq("OnCreatedWidget")
    expect(sub.event_name).to eq("CreatedWidget")
    expect(sub.async).to eq(false)
    expect(sub.block).to be_a(Proc)
  end

  it "supports async: true" do
    domain = Hecks.domain "SubDslAsync" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end

        on_event "CreatedWidget", async: true do |event|
          puts event.name
        end
      end
    end

    sub = domain.aggregates.first.subscribers.first
    expect(sub.async).to eq(true)
  end

  it "generates unique names for multiple subscribers on the same event" do
    domain = Hecks.domain "SubDslMulti" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end

        on_event "CreatedWidget" do |event|
          puts "first"
        end

        on_event "CreatedWidget" do |event|
          puts "second"
        end
      end
    end

    subs = domain.aggregates.first.subscribers
    expect(subs.size).to eq(2)
    expect(subs[0].name).to eq("OnCreatedWidget")
    expect(subs[1].name).to eq("OnCreatedWidget2")
  end

  it "defaults to empty subscribers" do
    domain = Hecks.domain "SubDslEmpty" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end

    expect(domain.aggregates.first.subscribers).to eq([])
  end
end
