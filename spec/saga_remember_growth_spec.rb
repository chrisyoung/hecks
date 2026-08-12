require "spec_helper"
require "tempfile"

# Real dispatch coverage for saga mutable memory (`remember`/`set`):
# SagaInterpreter's instance[:memory] was write-once before this PR --
# set from the starting event's payload at saga creation, never mutated
# again. A mid-saga handler can now hand a LATER tick something it
# decided, written into the saga instance's own carried memory. (The
# `from_pm` sugar to READ it back inside a later handler's own `with:`
# lands with a separate, later item in this split -- this coverage
# confirms the WRITE side directly.)
RSpec.describe "saga mutable memory via remember" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["saga-remember-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name, &binds)
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  SAGA_REMEMBER_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "RememberGrowth" do
      aggregate "GrowthOrder" do
        identified_by { id.value }

        value_object "GrowthOrderId" do
          attribute :value, String
        end

        attribute :id, GrowthOrderId

        command "Place" do
          attribute :id,      GrowthOrderId
          attribute :courier, String
          emits "Placed"
        end
      end

      process_manager "RememberSaga" do
        correlates_by :"id.value"
        starts_on "Placed"
        ends_on "Shipped"

        state "started"
        state "remembered"

        on "Placed", transition: { "started" => "remembered" } do
          remember chosen_courier: from_event(:courier)
        end
      end
    end
  BLUEBOOK

  it "carries a remembered value forward in the saga's own instance memory" do
    runtime = boot(SAGA_REMEMBER_SOURCE, "RememberGrowth") { ::RememberGrowth::GrowthOrder.persisted_by("Memory") }
    runtime.dispatch("RememberGrowth::GrowthOrder.Place", id: { value: "o1" }, courier: "SwiftPost")

    instance = runtime.registry.saga_instances["RememberSaga"]["o1"]

    expect(instance[:memory][:chosen_courier]).to eq("SwiftPost")
  end
end
