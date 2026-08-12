require "spec_helper"
require "tempfile"

# Real coverage for Handler's remembers/guard_count self-hosted round-trip:
# reaction.bluebook's own "Handler" aggregate never declared `remembers` or
# `guard_count`, so `remember key: from_event(...)` and a handler-level
# `given` had nowhere for the meta-validator's Judge/Reconstruction to
# write or read them back -- round_trip_spec caught it directly (Banking/
# Wire both diffed on `.handlers[N].remembers`/`.guard_count`, "declared
# [], read back nil").
RSpec.describe "Handler remembers/guard_count survive the Judge round-trip" do
  SAGA_REMEMBER_ROUND_TRIP_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "SagaRememberRoundTripGrowth" do
      aggregate "Widget" do
        identified_by { id.value }
        value_object "WidgetId" do
          attribute :value, String
        end
        attribute :id, WidgetId

        command "Open" do
          attribute :id, WidgetId
          emits "Opened"
        end
        command "Close" do
          reference_to Widget
          emits "Closed"
        end
      end

      process_manager "RememberGuardSaga" do
        correlates_by :"id.value"
        starts_on "Opened"
        ends_on "Closed"

        state "none"
        state "open"

        on "Opened", transition: { "none" => "open" } do
          remember owner: :id
          given { !id.to_s.empty? }
          dispatch "SagaRememberRoundTripGrowth::Widget.Close", with: { id: :id }
        end
      end
    end
  BLUEBOOK

  def build_bluebook
    file = Tempfile.new(["saga-remember-round-trip-growth-", ".bluebook"])
    file.write(SAGA_REMEMBER_ROUND_TRIP_SOURCE)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(SAGA_REMEMBER_ROUND_TRIP_SOURCE, TOPLEVEL_BINDING, file.path, 1)
    end
    registry.bluebook("SagaRememberRoundTripGrowth")
  ensure
    file&.close!
  end

  # `Hecksagain.bluebook`'s own `BluebookBuilder#build` already routes
  # through `MetaValidator.call` internally (meta-validation defaults ON)
  # -- so this is ALREADY a full Judge/Reconstruction round-trip, not a
  # bare DSL capture. Before the fix: declared non-empty, read back [] /
  # guard_count 0 -- "declared [], read back nil" is round_trip_spec's
  # own wording for this exact regression.
  it "the judged bluebook carries the handler's own remembers and guard_count" do
    bluebook = build_bluebook
    handler = bluebook.process_managers.first.handlers.first

    expect(handler.remembers).to eq(owner: :id)
    expect(handler.guard_count).to eq(1)
  end

  it "re-judging an already-judged bluebook is stable (idempotent round-trip)" do
    once = build_bluebook
    twice = Hecksagain::Bluebook::MetaValidator.call(once)
    handler = twice.process_managers.first.handlers.first

    expect(handler.remembers).to eq(owner: :id)
    expect(handler.guard_count).to eq(1)
  end
end
