require "spec_helper"
require "hecks/extensions/serve/sse_helpers"

RSpec.describe Hecks::HTTP::SseHelpers do
  let(:host_class) do
    Class.new do
      include Hecks::HTTP::SseHelpers

      attr_reader :sse_clients

      def initialize
        @sse_clients = []
        @lock = Mutex.new
      end
    end
  end

  subject(:host) { host_class.new }

  describe "#register_sse_broadcaster" do
    it "registers an on_any listener that broadcasts to SSE clients" do
      bus = Hecks::EventBus.new
      host.register_sse_broadcaster(bus)

      queue = Queue.new
      host.sse_clients << { queue: queue }

      event = double("event",
        class: double(name: "Test::CreatedWidget"),
        occurred_at: Time.new(2026, 4, 1, 12, 0, 0, "+00:00"))
      allow(Hecks::Utils).to receive(:const_short_name).with(event).and_return("CreatedWidget")

      bus.publish(event)

      msg = queue.pop(true) rescue nil
      expect(msg).to include("data:")
      expect(msg).to include("CreatedWidget")
      expect(msg).to end_with("\n\n")
    end
  end

  describe "#broadcast_sse" do
    it "sends message to all connected clients" do
      q1 = Queue.new
      q2 = Queue.new
      host.sse_clients << { queue: q1 }
      host.sse_clients << { queue: q2 }

      host.send(:broadcast_sse, "data: test\n\n")

      expect(q1.pop(true)).to eq("data: test\n\n")
      expect(q2.pop(true)).to eq("data: test\n\n")
    end

    it "handles empty client list gracefully" do
      expect { host.send(:broadcast_sse, "data: test\n\n") }.not_to raise_error
    end
  end

  describe "#serialize_event" do
    it "formats event as SSE data line with JSON" do
      event = double("event",
        class: double(name: "Pizzas::CreatedPizza"),
        occurred_at: Time.new(2026, 4, 1, 12, 0, 0, "+00:00"))

      allow(Hecks::Utils).to receive(:const_short_name).with(event).and_return("CreatedPizza")

      result = host.send(:serialize_event, event)
      expect(result).to start_with("data: ")
      expect(result).to end_with("\n\n")

      json = JSON.parse(result.sub("data: ", "").strip)
      expect(json["type"]).to eq("CreatedPizza")
      expect(json["occurred_at"]).to include("2026-04-01")
    end
  end
end
