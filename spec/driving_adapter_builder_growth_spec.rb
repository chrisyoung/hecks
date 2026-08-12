require "spec_helper"

# Real coverage for Hecksagain::Bluebook::DSL::DrivingAdapterBuilder: the
# driving-side adapter grammar (`adapter "X" do driving on cron/interval/
# http_post/file_watch "<arg>" do |signal| dispatch "Domain::Agg.Command"
# end end`) -- the inverse of persisted_by/charged_by's driven side, an
# external clock/file-watch/http-post reaching IN.
#
# `IR::DrivingHandler` (originally a much-later item in this split, from
# `03b5ffc`) is pulled forward into THIS PR as real plumbing this
# construct depends on to actually assemble -- same "plumbing ready
# before its feature" pattern as items 07b/12e -- so `#driving`'s own
# full assembly gets real, positive coverage here rather than a pinned
# "honest gap" placeholder.
RSpec.describe Hecksagain::Bluebook::DSL::DrivingAdapterBuilder do
  describe "the on/cron/interval/http_post/file_watch kind-arg capture" do
    it "captures each driving kind as a [kind, arg] pair via #on" do
      builder = described_class.new("InboxPoller")

      %w[cron interval http_post file_watch].each do |kind|
        pair = builder.public_send(kind, "some-arg")
        expect(pair).to eq([kind, "some-arg"])
      end
    end

    it "#on is a pure passthrough for the [kind, arg] pair" do
      builder = described_class.new("InboxPoller")
      expect(builder.on(%w[cron */5 * * * *])).to eq(%w[cron */5 * * * *])
    end
  end

  describe "DispatchCapture" do
    it "captures the single dispatch call's command FQN" do
      capture = described_class::DispatchCapture.new
      capture.instance_eval { dispatch "Inbox::Message.Poll" }
      expect(capture.command).to eq("Inbox::Message.Poll")
    end

    it "ignores dispatch's kwargs (structural capture, not yet threaded through)" do
      capture = described_class::DispatchCapture.new
      capture.instance_eval { dispatch "Inbox::Message.Poll", attr: :field }
      expect(capture.command).to eq("Inbox::Message.Poll")
    end
  end

  describe "catch-all custom-adapter-kind absorption" do
    it "swallows unknown configuration verbs rather than raising NoMethodError" do
      builder = described_class.new("DreamImage")
      expect { builder.instance_eval { prompt_template "some template" } }.not_to raise_error
    end

    it "still dispatches to a real method (on/cron/etc.) over method_missing" do
      builder = described_class.new("InboxPoller")
      expect(builder.cron("*/5 * * * *")).to eq(["cron", "*/5 * * * *"])
    end

    it "responds_to_missing? unconditionally, matching method_missing's own catch-all" do
      builder = described_class.new("DreamImage")
      expect(builder.respond_to?(:anything_at_all)).to be(true)
    end
  end

  describe "#build" do
    it "starts empty when no driving block ran" do
      handlers = described_class.build("InboxPoller") {}
      expect(handlers).to eq([])
    end
  end

  describe "#driving (full assembly)" do
    it "assembles a real IR::DrivingHandler from the on/dispatch pair" do
      handlers = described_class.build("InboxPoller") do
        driving on(cron("*/5 * * * *")) do
          dispatch "Inbox::Message.Poll"
        end
      end

      expect(handlers.size).to eq(1)
      handler = handlers.first
      expect(handler.adapter_name).to eq("InboxPoller")
      expect(handler.kind).to eq("cron")
      expect(handler.arg).to eq("*/5 * * * *")
      expect(handler.dispatch_command).to eq("Inbox::Message.Poll")
    end
  end

  describe "DSL wiring" do
    it "is required from dsl.rb and loadable at boot" do
      expect(defined?(Hecksagain::Bluebook::DSL::DrivingAdapterBuilder)).to eq("constant")
    end
  end
end
