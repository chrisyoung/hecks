require "spec_helper"
require "hecks/extensions/idempotency"

RSpec.describe "hecks_idempotency connection" do
  let(:domain) do
    Hecks.domain "IdempTest" do
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

  it "first call executes normally" do
    # Re-register to get a fresh cache
    Hecks.extension_registry.delete(:idempotency)
    load File.expand_path("../../../lib/hecks/extensions/idempotency.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:idempotency]&.call(
      Object.const_get("IdempTestDomain"), domain, app
    )

    result = app.run("CreateWidget", name: "Margherita")
    expect(result).not_to be_nil
    expect(app.events.size).to eq(1)
  end

  it "second identical call returns cached result without re-executing" do
    Hecks.extension_registry.delete(:idempotency)
    load File.expand_path("../../../lib/hecks/extensions/idempotency.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:idempotency]&.call(
      Object.const_get("IdempTestDomain"), domain, app
    )

    result1 = app.run("CreateWidget", name: "Margherita")
    result2 = app.run("CreateWidget", name: "Margherita")

    expect(result2).to eq(result1)
    expect(app.events.size).to eq(1)
  end

  it "different attributes are not deduplicated" do
    Hecks.extension_registry.delete(:idempotency)
    load File.expand_path("../../../lib/hecks/extensions/idempotency.rb", __FILE__)

    app = Hecks.load(domain)
    Hecks.extension_registry[:idempotency]&.call(
      Object.const_get("IdempTestDomain"), domain, app
    )

    app.run("CreateWidget", name: "Margherita")
    app.run("CreateWidget", name: "Pepperoni")

    expect(app.events.size).to eq(2)
  end
end
