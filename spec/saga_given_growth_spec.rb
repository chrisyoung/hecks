require "spec_helper"
require "tempfile"

# Real dispatch coverage for saga handler-level `given`: a precondition
# on its DISPATCHES, not on the transition itself -- the transition
# always happens when the event fires in the right from_state; `given`
# only decides whether this handler's dispatches actually fire.
RSpec.describe "saga handler-level given" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["saga-given-growth-", ".bluebook"])
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

  SAGA_GIVEN_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "GivenGrowth" do
      aggregate "GrowthAccount" do
        identified_by { id.value }

        value_object "GrowthAccountId" do
          attribute :value, String
        end

        attribute :id, GrowthAccountId

        command "Open" do
          attribute :id,      GrowthAccountId
          attribute :verified, String
          emits "Opened"
        end

        command "Activate" do
          reference_to GrowthAccount
          emits "Activated"
        end
      end

      process_manager "GivenSaga" do
        correlates_by :"id.value"
        starts_on "Opened"
        ends_on "Activated"

        state "opening"
        state "opened"

        on "Opened", transition: { "opening" => "opened" } do
          given { |ctx| ctx[:verified] == "yes" }
          dispatch "GrowthAccount.Activate", with: { id: :id }
        end
      end
    end
  BLUEBOOK

  def boot_given
    boot(SAGA_GIVEN_SOURCE, "GivenGrowth") { ::GivenGrowth::GrowthAccount.persisted_by("Memory") }
  end

  it "fires the dispatch when the given clause holds" do
    runtime = boot_given
    runtime.dispatch("GivenGrowth::GrowthAccount.Open", id: { value: "a1" }, verified: "yes")

    expect(runtime.registry.saga_log.any? { |entry| entry[:delivered] == true }).to be(true)
  end

  it "skips the dispatch -- and only the dispatch -- when the given clause does not hold" do
    runtime = boot_given
    runtime.dispatch("GivenGrowth::GrowthAccount.Open", id: { value: "a2" }, verified: "no")

    instance = runtime.registry.saga_instances["GivenSaga"]["a2"]
    expect(instance[:state]).to eq("opened")
    expect(runtime.registry.saga_log.last).to include(dispatched: false, reason: "given clause did not hold")
  end
end
