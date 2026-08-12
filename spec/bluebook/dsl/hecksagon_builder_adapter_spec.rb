require "hecksagain"

RSpec.describe Hecksagain::Bluebook::DSL::HecksagonBuilder do
  describe "adapter with a driving block" do
    it "builds a DrivingHandler per driving on <kind> declaration" do
      hecksagon = described_class.build("GrowthDomain") do
        adapter "Clock" do
          driving on cron("*/10 * * * *") do |_signal|
            dispatch "GrowthDomain::Thing.Tick"
          end
        end
      end

      expect(hecksagon.driving_handlers.size).to eq(1)
      handler = hecksagon.driving_handlers.first
      expect(handler.adapter_name).to eq("Clock")
      expect(handler.kind).to eq("cron")
      expect(handler.arg).to eq("*/10 * * * *")
      expect(handler.dispatch_command).to eq("GrowthDomain::Thing.Tick")
    end

    it "supports interval/http_post/file_watch kinds too" do
      hecksagon = described_class.build("GrowthDomain") do
        adapter "Poller" do
          driving on interval("30s") do
            dispatch "GrowthDomain::Thing.Poll"
          end
        end
      end

      handler = hecksagon.driving_handlers.first
      expect(handler.kind).to eq("interval")
      expect(handler.arg).to eq("30s")
    end
  end

  describe "adapter with no block, an old-style raw adapter call" do
    it "records kind + opts on the builder rather than raising NoMethodError" do
      builder = described_class.new("GrowthDomain")
      builder.adapter(:stripe, api_key: "sk_test")

      expect(builder.raw_adapters).to eq([{ kind: "stripe", opts: { api_key: "sk_test" } }])
      expect(builder.driving_handlers).to be_empty
    end
  end
end
