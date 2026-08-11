require "spec_helper"

# Real coverage for docs/hecks-migration-findings.md items 6-9: saga memory
# used to be write-once, filled only from the starting event's payload at
# `begin_saga` and never touched again. This fork added three things that
# together make it genuinely mutable across a saga's whole lifetime —
#
#   1. `remember key: from_event(...)` — a MID-saga handler writes forward
#      into the instance's own carried memory.
#   2. `from_pm(:field, default:)` — a LATER handler reads a value back out
#      of that memory, the third sibling of `from_event`/`from_iter`.
#   3. Handler-level `given { |ctx| ... }` — gates a handler's DISPATCHES
#      only ; the transition and any `remember`s happen regardless.
#   4. `template("fmt %s", from_pm(...))` — composes a literal string with a
#      saga-memory value inside a `with:` argument.
#
# Each `it` below drives a small saga through two or three real ticks via
# `runtime.dispatch`, the same idiom `spec/runtime/saga_spec.rb` and
# `spec/runtime/correlation_key_spec.rb` already use — a bluebook declared
# inline, booted through `Hecksagain.with_registry`, dispatched for real.
RSpec.describe "saga memory that grows across ticks" do
  # A package is requested (tick 1, starts_on — carries only `code`), staged
  # at some depot (tick 2 — a DIFFERENT event, carrying `depot`, a field
  # `PackageRequested` never had), then loaded (tick 3 — a THIRD event,
  # carrying neither `depot` nor `origin`). The middle tick `remember`s the
  # depot as `origin` ; the last tick reads it back via `from_pm` and hands
  # it to a dispatched command. If memory were still write-once-at-creation,
  # `origin` would never exist at all — `PackageRequested`'s own payload
  # never carried it, so there would be nothing to fall back to.
  def boot_depot
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)

      Hecks.bluebook "Depot" do
        vision "A package moves from request to a carrier ; something remembers which depot staged it."
        supporting

        aggregate "Package" do
          identified_by { code.value }

          attribute :code, PackageCode

          value_object "PackageCode" do
            attribute :value, String
          end

          value_object "DepotName" do
            attribute :value, String
          end

          command "Request" do
            attribute :code, PackageCode
            emits "PackageRequested"
          end

          command "Stage" do
            reference_to Package
            attribute :depot, DepotName
            emits "PackageStaged"
          end

          command "Load" do
            reference_to Package
            emits "PackageLoaded"
          end
        end

        aggregate "Carrier" do
          identified_by { label.value }

          attribute :label, CarrierLabel
          attribute :assigned_from, CarrierOrigin, default: { value: "" }

          value_object "CarrierLabel" do
            attribute :value, String
          end

          value_object "CarrierOrigin" do
            attribute :value, String
          end

          command "Assign" do
            attribute :label, CarrierLabel
            attribute :assigned_from, CarrierOrigin
            emits "CarrierAssigned"
          end
        end

        process_manager "Route" do
          correlates_by :"code.value"
          starts_on "PackageRequested"
          ends_on   "CarrierAssigned"

          state "requested"
          state "staged"
          state "loaded"

          on "PackageStaged", transition: { "requested" => "staged" } do
            remember origin: from_event(:"depot.value")
          end

          on "PackageLoaded", transition: { "staged" => "loaded" } do
            dispatch "Depot::Carrier.Assign",
                     with: { label: { value: "truck-1" }, assigned_from: from_pm(:origin) }
          end
        end
      end

      Hecksagain::Runtime::Loader.bind_runtime(
        Hecksagain::Runtime::Dispatcher.new(registry)
      )
    end
  end

  it "reads back, on a later tick, a value a mid-saga handler wrote — memory is mutable, not write-once" do
    runtime = boot_depot
    runtime.dispatch("Depot::Package.Request", code: { value: "PKG-1" })
    runtime.dispatch("Depot::Package.Stage",   code: "PKG-1", depot: "north-9")
    runtime.dispatch("Depot::Package.Load",    code: "PKG-1")

    expect(Depot::Carrier.find("truck-1").assigned_from.value).to eq("north-9")

    expect(runtime.sagas).to include(
      hash_including(process_manager: "Route", instance: "PKG-1",
                     dispatch: "Depot::Carrier.Assign", delivered: true)
    )
    expect(runtime.registry.saga_instances["Route"]).to be_empty
  end
end

RSpec.describe "handler-level given gates the dispatch only" do
  # A watch pings at some loudness (tick 2). The handler always transitions
  # and always `remember`s the loudness ; only its `dispatch` — a siren — is
  # gated on whether the ping was loud. Two full saga instances, one per
  # branch, prove the split: the transition/remember happen either way, the
  # dispatch fires on exactly one of them. A later `Close` (tick 3) ends
  # both sagas the same way regardless of which branch the middle tick took.
  def boot_sentry
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)

      Hecks.bluebook "Sentry" do
        vision "A watch pings, and a siren blares only when the ping was loud."
        supporting

        aggregate "Watch" do
          identified_by { tag.value }

          attribute :tag, WatchTag

          value_object "WatchTag" do
            attribute :value, String
          end

          value_object "Loudness" do
            attribute :value, String
          end

          command "Open" do
            attribute :tag, WatchTag
            emits "WatchOpened"
          end

          command "Ping" do
            reference_to Watch
            attribute :loudness, Loudness
            emits "WatchPinged"
          end

          command "Close" do
            reference_to Watch
            emits "WatchClosed"
          end
        end

        aggregate "Siren" do
          identified_by { label.value }

          attribute :label, SirenLabel

          value_object "SirenLabel" do
            attribute :value, String
          end

          command "Blare" do
            attribute :label, SirenLabel
            emits "SirenBlared"
          end
        end

        process_manager "Alertness" do
          correlates_by :"tag.value"
          starts_on "WatchOpened"
          ends_on   "WatchClosed"

          state "quiet"
          state "pinged"
          state "closed"

          on "WatchPinged", transition: { "quiet" => "pinged" } do
            given { |ctx| ctx[:loudness][:value] == "loud" }
            remember note: from_event(:"loudness.value")
            dispatch "Sentry::Siren.Blare", with: { label: :tag }
          end

          on "WatchClosed", transition: { "pinged" => "closed" }
        end
      end

      Hecksagain::Runtime::Loader.bind_runtime(
        Hecksagain::Runtime::Dispatcher.new(registry)
      )
    end
  end

  it "fires the dispatch when the given clause holds" do
    runtime = boot_sentry
    runtime.dispatch("Sentry::Watch.Open", tag: { value: "loud-1" })
    runtime.dispatch("Sentry::Watch.Ping", tag: "loud-1", loudness: "loud")

    expect(runtime.sagas).to include(
      hash_including(process_manager: "Alertness", instance: "loud-1",
                     advanced: true, from: "quiet", to: "pinged")
    )
    expect(runtime.sagas).to include(
      hash_including(process_manager: "Alertness", instance: "loud-1",
                     dispatch: "Sentry::Siren.Blare", delivered: true)
    )
    expect(Sentry::Siren.find("loud-1").label.value).to eq("loud-1")
    expect(runtime.registry.saga_instances["Alertness"]["loud-1"][:memory][:note]).to eq("loud")

    runtime.dispatch("Sentry::Watch.Close", tag: "loud-1")
    expect(runtime.registry.saga_instances["Alertness"]).not_to have_key("loud-1")
  end

  it "still transitions and remembers when the given clause does not hold — only the dispatch is skipped" do
    runtime = boot_sentry
    runtime.dispatch("Sentry::Watch.Open", tag: { value: "quiet-1" })
    runtime.dispatch("Sentry::Watch.Ping", tag: "quiet-1", loudness: "hush")

    expect(runtime.sagas).to include(
      hash_including(process_manager: "Alertness", instance: "quiet-1",
                     advanced: true, from: "quiet", to: "pinged")
    )
    expect(runtime.sagas).to include(
      hash_including(process_manager: "Alertness", instance: "quiet-1",
                     dispatched: false, reason: "given clause did not hold")
    )
    expect(runtime.registry.saga_instances["Alertness"]["quiet-1"][:memory][:note]).to eq("hush")

    expect(Sentry::Siren.find("quiet-1")).to be_nil

    runtime.dispatch("Sentry::Watch.Close", tag: "quiet-1")
    expect(runtime.registry.saga_instances["Alertness"]).not_to have_key("quiet-1")
  end
end

RSpec.describe "template composes a literal with a saga-memory value" do
  # A notice is raised with a region (tick 1, also `remember`s it — through
  # the DOTTED `from_event(:"region.value")` path, so memory holds the bare
  # scalar rather than a wrapped Value that `template`'s `format` would
  # otherwise render as a raw object pointer). Confirmed later (tick 2), a
  # DIFFERENT event whose own payload carries no region at all — the
  # dispatched `Board.Post` composes a literal with the remembered region
  # entirely from saga memory.
  def boot_bulletin
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)

      Hecks.bluebook "Bulletin" do
        vision "A notice is raised for a region, confirmed later, and posted with a composed caption."
        supporting

        aggregate "Notice" do
          identified_by { code.value }

          attribute :code, NoticeCode

          value_object "NoticeCode" do
            attribute :value, String
          end

          value_object "Region" do
            attribute :value, String
          end

          command "Raise" do
            attribute :code, NoticeCode
            attribute :region, Region
            emits "NoticeRaised"
          end

          command "Confirm" do
            reference_to Notice
            emits "NoticeConfirmed"
          end
        end

        aggregate "Board" do
          identified_by { slot.value }

          attribute :slot, BoardSlot
          attribute :caption, Caption, default: { value: "" }

          value_object "BoardSlot" do
            attribute :value, String
          end

          value_object "Caption" do
            attribute :value, String
          end

          command "Post" do
            attribute :slot, BoardSlot
            attribute :caption, Caption
            emits "NoticePosted"
          end
        end

        process_manager "Broadcast" do
          correlates_by :"code.value"
          starts_on "NoticeRaised"
          ends_on   "NoticePosted"

          state "raised"
          state "confirmed"
          state "posted"

          on "NoticeRaised", transition: { "raised" => "raised" } do
            remember region: from_event(:"region.value")
          end

          on "NoticeConfirmed", transition: { "raised" => "confirmed" } do
            dispatch "Bulletin::Board.Post",
                     with: { slot: { value: "main" }, caption: template("Notice from %s", from_pm(:region)) }
          end
        end
      end

      Hecksagain::Runtime::Loader.bind_runtime(
        Hecksagain::Runtime::Dispatcher.new(registry)
      )
    end
  end

  it "hands the dispatched command the fully-composed string" do
    runtime = boot_bulletin
    runtime.dispatch("Bulletin::Notice.Raise", code: { value: "note-1" }, region: { value: "north-9" })
    runtime.dispatch("Bulletin::Notice.Confirm", code: "note-1")

    expect(Bulletin::Board.find("main").caption.value).to eq("Notice from north-9")
    expect(runtime.registry.saga_instances["Broadcast"]).to be_empty
  end
end
