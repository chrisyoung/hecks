require "spec_helper"

# Real coverage for the DreamImage adapter registration: miette's own
# body/dream/bluebook/dream.hecksagon declares
# `BodyDream::Dream.imaged_by("DreamImage", on: "DreamImageRequested")`,
# but no `.port`/`.adapter` pair existed for it to resolve against -- a
# real bind naming it failed the wiring gate with "unknown adapter".
# The actual image-generation call is real, external, off-core handler
# machinery this registration only DECLARES the contract for -- same
# shape as screenshot_buffer.port/payment.port, part of this migration's
# single biggest confirmed-unimplemented gap (the effect-family
# success/failure re-entry, still a structural stub).
RSpec.describe "the DreamImage adapter and dream_image port" do
  def registry_with_real_library
    registry = Hecksagain::Runtime::Registry.new
    loading = Hecksagain::Ports::Loading.bootstrap
    Hecksagain.with_registry(registry) { loading.load_library }
    registry
  end

  it "resolves an imaged_by bind naming DreamImage without a WiringError" do
    registry = registry_with_real_library

    bind = Hecksagain::Bluebook::IR::Bind.new(
      aggregate: "BodyDream::Dream", verb: "imaged_by", adapter: "DreamImage", role: nil
    )

    expect { registry.check_verb(bind) }.not_to raise_error
  end

  it "the dream_image port declares imaged_by as an effect signal" do
    registry = registry_with_real_library

    port = registry.ports["dream_image"]
    expect(port.verb).to eq("imaged_by")
    expect(port.effect?).to be(true)
  end

  it "refuses a bind naming DreamImage for the wrong verb" do
    registry = registry_with_real_library

    bind = Hecksagain::Bluebook::IR::Bind.new(
      aggregate: "BodyDream::Dream", verb: "persisted_by", adapter: "DreamImage", role: nil
    )

    expect { registry.check_verb(bind) }.to raise_error(
      Hecksagain::Runtime::WiringError, /DreamImage implements the dream_image port.*cannot satisfy persisted_by/m
    )
  end
end
