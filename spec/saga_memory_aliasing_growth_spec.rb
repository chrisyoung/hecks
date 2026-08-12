require "spec_helper"
require "tempfile"

# Real coverage for a saga's begin_saga aliasing bug: seeding a fresh saga
# instance's `memory:` with `event.payload` directly (the SAME Hash
# object, not a copy) meant `remember_into_instance` -- which writes into
# `instance[:memory]` in place -- could retroactively add a field to the
# STARTING event's own `.payload`, an event already emitted and logged
# before the saga ever saw it. `.dup` on the way into `memory:` fixes it.
RSpec.describe "a saga's begin_saga does not alias the starting event's payload" do
  SAGA_MEMORY_ALIASING_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "SagaMemoryAliasingGrowth" do
      aggregate "Widget" do
        identified_by { widget_id.value }
        value_object "WidgetId" do
          attribute :value, String
        end
        attribute :widget_id, WidgetId

        command "Open" do
          attribute :widget_id, WidgetId
          emits "Opened"
        end
        command "Close" do
          reference_to Widget
          emits "Closed"
        end
      end

      process_manager "AliasingSaga" do
        correlates_by :"widget_id.value"
        starts_on "Opened"
        ends_on "Closed"

        state "none"
        state "open"

        # THE EXACT SHAPE THAT TRIGGERS THE BUG: remember declared on the
        # SAME leg that STARTS the saga -- remember_into_instance writes
        # into instance[:memory], and without the fix that write landed on
        # the STARTING event's own already-emitted .payload too.
        on "Opened", transition: { "none" => "open" } do
          remember owner: :widget_id
          dispatch "SagaMemoryAliasingGrowth::Widget.Close", with: { widget_id: :widget_id }
        end
      end
    end
  BLUEBOOK

  def boot
    file = Tempfile.new(["saga-memory-aliasing-growth-", ".bluebook"])
    file.write(SAGA_MEMORY_ALIASING_SOURCE)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(SAGA_MEMORY_ALIASING_SOURCE, TOPLEVEL_BINDING, file.path, 1)
    end
    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(Hecksagain::Runtime::Dispatcher.new(registry))
  ensure
    file&.close!
  end

  it "does not mutate the starting event's own payload when the leg remembers a field" do
    runtime = boot
    runtime.dispatch("SagaMemoryAliasingGrowth::Widget.Open", widget_id: { value: "widget-1" })

    opened = runtime.events.find { |e| e.name == "Opened" }
    expect(opened).not_to be_nil

    # Before the fix: `remember owner: :widget_id` on the SAME starting leg wrote
    # `owner` straight into this already-emitted event's own payload Hash,
    # since begin_saga seeded memory: with the SAME object, not a copy.
    expect(opened.payload).not_to have_key(:owner)
  end

  it "the saga's own memory still carries the remembered field (the fix does not break the feature)" do
    runtime = boot
    runtime.dispatch("SagaMemoryAliasingGrowth::Widget.Open", widget_id: { value: "widget-1" })

    instance = runtime.registry.saga_instances["AliasingSaga"]["widget-1"]
    expect(instance).to be_nil # ended immediately (starts_on == ends_on's leg dispatches Close)

    # the saga log itself proves the instance existed and was born with
    # the leg's own dispatch having fired
    expect(runtime.sagas).to include(hash_including(process_manager: "AliasingSaga", born: true))
  end
end
