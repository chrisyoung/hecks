require "spec_helper"
require "tempfile"

# Real coverage for BindingProxy's `Aggregate.event_sourced` marker verb
# -- "this aggregate's own event log IS its persistence, no separate
# backend choice needed." Every other bind verb needs a real adapter
# name (`args.first`); `event_sourced` structurally never supplies one,
# so the generic path would mint an empty-string adapter and fail
# wiring ("unknown adapter \"\""). Sugar for `persisted_by("Heki")`.
#
# ADDITIVE-ONLY: an aggregate that already carries an explicit
# `persisted_by` bind (any adapter) is NOT double-bound by a trailing
# `.event_sourced` -- the two statements OVERLAY, they don't duplicate
# or replace. `event_sourced` alone (no other persistence statement) is
# what actually mints the Heki bind.
RSpec.describe "BindingProxy Aggregate.event_sourced" do
  def boot(source, &binds)
    file = Tempfile.new(["event-sourced-sugar-growth-", ".bluebook"])
    file.write(source)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon("EventSourcedSugarGrowth", &binds)
    end
    registry
  ensure
    file&.close!
  end

  EVENT_SOURCED_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "EventSourcedSugarGrowth" do
      aggregate "Ledger" do
        identified_by { ledger_id.value }
        value_object "LedgerId" do
          attribute :value, String
        end
        attribute :ledger_id, LedgerId
      end

      aggregate "Overlay" do
        identified_by { overlay_id.value }
        value_object "OverlayId" do
          attribute :value, String
        end
        attribute :overlay_id, OverlayId
      end
    end
  BLUEBOOK

  it "mints a real persisted_by(Heki) bind when it's the ONLY persistence statement" do
    registry = boot(EVENT_SOURCED_SOURCE) do
      ::EventSourcedSugarGrowth::Ledger.event_sourced
    end

    bind = registry.hecksagon("EventSourcedSugarGrowth").bind_for("Ledger", "persisted_by")
    expect(bind).not_to be_nil
    expect(bind.adapter).to eq("Heki")
  end

  it "does NOT double-bind when an explicit persisted_by already exists on the same aggregate" do
    registry = boot(EVENT_SOURCED_SOURCE) do
      ::EventSourcedSugarGrowth::Overlay.persisted_by("Heki")
      ::EventSourcedSugarGrowth::Overlay.event_sourced
    end

    binds = registry.hecksagon("EventSourcedSugarGrowth").binds_for("Overlay", "persisted_by")
    expect(binds.size).to eq(1)
  end

  it "the bare marker verb never leaks an empty-string adapter" do
    registry = boot(EVENT_SOURCED_SOURCE) do
      ::EventSourcedSugarGrowth::Ledger.event_sourced
    end

    bind = registry.hecksagon("EventSourcedSugarGrowth").bind_for("Ledger", "persisted_by")
    expect(bind.adapter).not_to eq("")
  end
end
