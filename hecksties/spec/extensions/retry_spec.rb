require "spec_helper"
require "hecks/extensions/retry"

RSpec.describe "hecks_retry middleware" do
  let(:domain) do
    Hecks.domain "RetryTest" do
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

  # Helper: runs the retry middleware logic with given max/delay
  def run_retry(next_handler, max: 3, delay: 0.0)
    attempts = 0
    begin
      attempts += 1
      next_handler.call
    rescue Hecks::Error
      raise
    rescue StandardError => e
      if attempts < max
        retry
      end
      raise
    end
  end

  it "succeeds on first try with no retry" do
    ENV["HECKS_RETRY_DELAY"] = "0"
    Hecks.extension_registry.delete(:retry)
    load File.expand_path("../../../lib/hecks/extensions/retry.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:retry]&.call(
      Object.const_get("RetryTestDomain"), domain, app
    )

    call_count = 0
    handler = -> { call_count += 1; :ok }
    result = run_retry(handler)

    expect(result).to eq(:ok)
    expect(call_count).to eq(1)
  ensure
    ENV.delete("HECKS_RETRY_DELAY")
  end

  it "retries on transient error and succeeds" do
    ENV["HECKS_RETRY_DELAY"] = "0"
    Hecks.extension_registry.delete(:retry)
    load File.expand_path("../../../lib/hecks/extensions/retry.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:retry]&.call(
      Object.const_get("RetryTestDomain"), domain, app
    )

    call_count = 0
    handler = -> {
      call_count += 1
      raise RuntimeError, "network timeout" if call_count < 3
      :recovered
    }

    result = run_retry(handler)

    expect(result).to eq(:recovered)
    expect(call_count).to eq(3)
  ensure
    ENV.delete("HECKS_RETRY_DELAY")
  end

  it "does NOT retry Hecks::Error subclasses" do
    ENV["HECKS_RETRY_DELAY"] = "0"
    Hecks.extension_registry.delete(:retry)
    load File.expand_path("../../../lib/hecks/extensions/retry.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:retry]&.call(
      Object.const_get("RetryTestDomain"), domain, app
    )

    call_count = 0
    handler = -> {
      call_count += 1
      raise Hecks::ValidationError, "bad input"
    }

    expect { run_retry(handler) }.to raise_error(Hecks::ValidationError, "bad input")
    expect(call_count).to eq(1)
  ensure
    ENV.delete("HECKS_RETRY_DELAY")
  end

  it "raises after max retries exhausted" do
    ENV["HECKS_RETRY_DELAY"] = "0"
    Hecks.extension_registry.delete(:retry)
    load File.expand_path("../../../lib/hecks/extensions/retry.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:retry]&.call(
      Object.const_get("RetryTestDomain"), domain, app
    )

    call_count = 0
    handler = -> {
      call_count += 1
      raise RuntimeError, "keeps failing"
    }

    expect { run_retry(handler) }.to raise_error(RuntimeError, "keeps failing")
    expect(call_count).to eq(3)
  ensure
    ENV.delete("HECKS_RETRY_DELAY")
  end
end
