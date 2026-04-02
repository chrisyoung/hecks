require "spec_helper"
require "hecks/extensions/serve/sse_handler"

RSpec.describe Hecks::HTTP::SSEHandler do
  let(:handler) { Hecks::HTTP::SSEHandler.new }

  it "starts with zero clients" do
    expect(handler.client_count).to eq(0)
  end

  it "subscribes to event bus and broadcasts events" do
    domain = Hecks.domain("SSETest") do
      aggregate "Widget" do
        attribute :label, String
        command "CreateWidget" do
          attribute :label, String
        end
      end
    end
    runtime = Hecks.load(domain)
    handler.subscribe(runtime.event_bus)

    # Simulate a client connection using a queue directly
    queue = Queue.new
    handler.instance_variable_get(:@clients) << queue

    runtime.run("CreateWidget", label: "Test")

    frame = queue.pop
    expect(frame).to include("CreatedWidget")
    expect(frame).to start_with("data: ")
  end
end

RSpec.describe Hecks::HTTP::StreamBody do
  it "yields retry header then queued frames" do
    queue = Queue.new
    queue << "data: {\"type\":\"Test\"}\n\n"
    queue << nil # sentinel to end stream

    body = Hecks::HTTP::StreamBody.new(queue)
    chunks = []
    body.each { |chunk| chunks << chunk }

    expect(chunks.first).to eq("retry: 1000\n\n")
    expect(chunks[1]).to include("Test")
    expect(chunks.size).to eq(2)
  end
end
