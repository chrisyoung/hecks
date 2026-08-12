require "spec_helper"

# Real coverage for the DiskBuffer adapter registration: the out-of-
# process handler web_debug.hecksagon's own
# `Screenshot.buffered_by("DiskBuffer", on: "FrameCaptured")` names it,
# but before this there was no `.port`/`.adapter` pair for it to resolve
# against, so a real bind naming it failed the wiring gate with "unknown
# adapter". The actual handler process (writing frames to disk, pruning
# old ones) is real, external, off-core machinery this registration only
# DECLARES the contract for -- same shape as the still-unimplemented
# success/failure async-verdict re-entry the whole effect-family
# subsystem needs, so no Ruby adapter CLASS is required here (verify!
# never calls adapter_class for a non-persistence-verb bind).
RSpec.describe "the DiskBuffer adapter and screenshot_buffer port" do
  def registry_with_real_library
    registry = Hecksagain::Runtime::Registry.new
    loading = Hecksagain::Ports::Loading.bootstrap
    Hecksagain.with_registry(registry) { loading.load_library }
    registry
  end

  it "resolves a buffered_by bind naming DiskBuffer without a WiringError" do
    registry = registry_with_real_library

    bind = Hecksagain::Bluebook::IR::Bind.new(
      aggregate: "WebDebug::Screenshot", verb: "buffered_by", adapter: "DiskBuffer", role: nil
    )

    expect { registry.check_verb(bind) }.not_to raise_error
  end

  it "the screenshot_buffer port declares buffered_by as an effect signal" do
    registry = registry_with_real_library

    port = registry.ports["screenshot_buffer"]
    expect(port.verb).to eq("buffered_by")
    expect(port.effect?).to be(true)
  end

  it "refuses a bind naming DiskBuffer for the wrong verb" do
    registry = registry_with_real_library

    bind = Hecksagain::Bluebook::IR::Bind.new(
      aggregate: "WebDebug::Screenshot", verb: "persisted_by", adapter: "DiskBuffer", role: nil
    )

    expect { registry.check_verb(bind) }.to raise_error(
      Hecksagain::Runtime::WiringError, /DiskBuffer implements the screenshot_buffer port.*cannot satisfy persisted_by/m
    )
  end
end
