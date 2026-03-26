require "spec_helper"

RSpec.describe "Async policies" do
  let(:domain) do
    Hecks.domain "AsyncPolicies" do
      aggregate "Order" do
        attribute :item, String

        command "PlaceOrder" do
          attribute :item, String
        end

        command "NotifyWarehouse" do
          attribute :item, String
        end

        policy "ShipOrder" do
          on "PlacedOrder"
          trigger "NotifyWarehouse"
          async true
        end
      end
    end
  end

  it "calls the async handler instead of dispatching inline" do
    calls = []
    app = Hecks.load(domain, force: true)
    app.async do |command_name, attrs|
      calls << { command: command_name, attrs: attrs }
    end

    app.run("PlaceOrder", item: "Widget")

    expect(calls.size).to eq(1)
    expect(calls[0][:command]).to eq("NotifyWarehouse")
    expect(calls[0][:attrs][:item]).to eq("Widget")
  end

  it "falls back to inline dispatch when no async handler is set" do
    app = Hecks.load(domain, force: true)
    app.run("PlaceOrder", item: "Widget")

    event_names = app.events.map { |e| e.class.name.split("::").last }
    expect(event_names).to include("PlacedOrder")
    expect(event_names).to include("NotifiedWarehouse")
  end

  it "sync policies still dispatch inline even with an async handler" do
    sync_domain = Hecks.domain "SyncAsync" do
      aggregate "Task" do
        attribute :title, String

        command "CreateTask" do
          attribute :title, String
        end

        command "LogTask" do
          attribute :title, String
        end

        policy "AutoLog" do
          on "CreatedTask"
          trigger "LogTask"
        end
      end
    end

    app = Hecks.load(sync_domain, force: true)
    app.async { |cmd, attrs| raise "should not be called" }

    app.run("CreateTask", title: "Test")
    event_names = app.events.map { |e| e.class.name.split("::").last }
    expect(event_names).to include("LoggedTask")
  end

  it "is available in the DSL" do
    policy = domain.aggregates.first.policies.first
    expect(policy.async).to eq(true)
  end

  it "defaults to sync" do
    sync_domain = Hecks.domain "DefaultSync" do
      aggregate "Item" do
        attribute :name, String
        command "CreateItem" do
          attribute :name, String
        end
        command "LogItem" do
          attribute :name, String
        end
        policy "AutoLog" do
          on "CreatedItem"
          trigger "LogItem"
        end
      end
    end

    policy = sync_domain.aggregates.first.policies.first
    expect(policy.async).to eq(false)
  end

  it "serializes async flag in DSL" do
    source = Hecks::DslSerializer.new(domain).serialize
    expect(source).to include("async true")
  end
end
