require "spec_helper"
require "hecks/extensions/web_explorer/event_introspector"

RSpec.describe Hecks::WebExplorer::EventIntrospector do
  let(:domain) do
    Hecks.domain "EventViewTest" do
      aggregate "Task" do
        attribute :title, String
        command "CreateTask" do
          attribute :title, String
        end
      end
    end
  end

  let(:runtime) { Hecks.load(domain) }
  let(:introspector) { Hecks::WebExplorer::EventIntrospector.new(runtime.event_bus) }

  it "returns empty events when nothing published" do
    expect(introspector.recent_events).to be_empty
    expect(introspector.event_count).to eq(0)
  end

  it "returns events after commands are executed" do
    runtime.run("CreateTask", title: "Write specs")
    events = introspector.recent_events
    expect(events.size).to eq(1)
    expect(events.first[:type]).to eq("CreatedTask")
    expect(events.first[:occurred_at]).to be_a(String)
  end

  it "returns events in reverse chronological order" do
    runtime.run("CreateTask", title: "First")
    runtime.run("CreateTask", title: "Second")
    events = introspector.recent_events
    expect(events.size).to eq(2)
    # Most recent first
    expect(events.first[:type]).to eq("CreatedTask")
  end

  it "respects the limit parameter" do
    5.times { |i| runtime.run("CreateTask", title: "Task #{i}") }
    events = introspector.recent_events(limit: 3)
    expect(events.size).to eq(3)
  end

  it "reports total event count" do
    3.times { |i| runtime.run("CreateTask", title: "Task #{i}") }
    expect(introspector.event_count).to eq(3)
  end
end
