require "spec_helper"
require "hecks/extensions/rate_limit"

RSpec.describe "hecks_rate_limit connection" do
  let(:domain) do
    Hecks.domain "RateTest" do
      aggregate "Widget" do
        attribute :name, String
        command "CreateWidget" do
          attribute :name, String
        end
      end
    end
  end

  after do
    Hecks.actor = nil
    Hecks.tenant = nil
  end

  it "allows commands under the limit" do
    ENV["HECKS_RATE_LIMIT"] = "5"
    ENV["HECKS_RATE_PERIOD"] = "60"

    # Re-register with new ENV values
    Hecks.extension_registry.delete(:rate_limit)
    load File.expand_path("../../../lib/hecks/extensions/rate_limit.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:rate_limit]&.call(
      Object.const_get("RateTestDomain"), domain, app
    )
    Hecks.actor = "user-1"

    3.times { |i| app.run("CreateWidget", name: "Widget #{i}") }
    expect(app.events.size).to eq(3)
  ensure
    ENV.delete("HECKS_RATE_LIMIT")
    ENV.delete("HECKS_RATE_PERIOD")
  end

  it "raises RateLimitExceeded when limit exceeded" do
    ENV["HECKS_RATE_LIMIT"] = "2"
    ENV["HECKS_RATE_PERIOD"] = "60"

    Hecks.extension_registry.delete(:rate_limit)
    load File.expand_path("../../../lib/hecks/extensions/rate_limit.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:rate_limit]&.call(
      Object.const_get("RateTestDomain"), domain, app
    )
    Hecks.actor = "user-2"

    2.times { |i| app.run("CreateWidget", name: "Widget #{i}") }
    expect {
      app.run("CreateWidget", name: "Widget extra")
    }.to raise_error(Hecks::RateLimitExceeded, /Rate limit exceeded/)
  ensure
    ENV.delete("HECKS_RATE_LIMIT")
    ENV.delete("HECKS_RATE_PERIOD")
  end

  it "does not rate limit when no actor set" do
    ENV["HECKS_RATE_LIMIT"] = "1"
    ENV["HECKS_RATE_PERIOD"] = "60"

    Hecks.extension_registry.delete(:rate_limit)
    load File.expand_path("../../../lib/hecks/extensions/rate_limit.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:rate_limit]&.call(
      Object.const_get("RateTestDomain"), domain, app
    )
    Hecks.actor = nil

    3.times { |i| app.run("CreateWidget", name: "Widget #{i}") }
    expect(app.events.size).to eq(3)
  ensure
    ENV.delete("HECKS_RATE_LIMIT")
    ENV.delete("HECKS_RATE_PERIOD")
  end
end
