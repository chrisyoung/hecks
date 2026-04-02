require "spec_helper"
require "sequel"

RSpec.describe "EventRecorder with upcasting" do
  let(:domain) do
    Hecks.domain "PizzaUpcast" do
      aggregate "Pizza" do
        attribute :name, String
        attribute :description, String

        event "CreatedPizza" do
          schema_version 2
          attribute :name, String
          attribute :description, String
        end

        command "CreatePizza" do
          attribute :name, String
          attribute :description, String
        end
      end

      upcast "CreatedPizza", from: 1, to: 2 do |data|
        data.merge("description" => data.delete("style") || "unknown")
      end
    end
  end

  let(:db) { Sequel.sqlite }
  let(:engine) { Hecks::Events::BuildEngine.call(domain) }
  let(:recorder) { Hecks::Persistence::EventRecorder.new(db, upcaster_engine: engine, domain: domain) }

  # Ensure the recorder (and table) exist before inserting raw data
  before { recorder }

  it "upcasts old events on read" do
    db[:domain_events].insert(
      stream_id: "Pizza-1",
      event_type: "CreatedPizza",
      data: '{"name":"Margherita","style":"Napoli"}',
      occurred_at: Time.now.iso8601,
      version: 1,
      schema_version: 1
    )

    history = recorder.history("Pizza", "1")
    expect(history.size).to eq(1)
    expect(history.first[:data]["description"]).to eq("Napoli")
    expect(history.first[:data]).not_to have_key("style")
    expect(history.first[:schema_version]).to eq(2)
  end

  it "leaves current-version events unchanged" do
    db[:domain_events].insert(
      stream_id: "Pizza-2",
      event_type: "CreatedPizza",
      data: '{"name":"Pepperoni","description":"Spicy"}',
      occurred_at: Time.now.iso8601,
      version: 1,
      schema_version: 2
    )

    history = recorder.history("Pizza", "2")
    expect(history.first[:data]["description"]).to eq("Spicy")
  end

  it "upcasts events in all_events" do
    db[:domain_events].insert(
      stream_id: "Pizza-1",
      event_type: "CreatedPizza",
      data: '{"name":"M","style":"Classic"}',
      occurred_at: Time.now.iso8601,
      version: 1,
      schema_version: 1
    )

    events = recorder.all_events
    expect(events.first[:data]["description"]).to eq("Classic")
  end
end
