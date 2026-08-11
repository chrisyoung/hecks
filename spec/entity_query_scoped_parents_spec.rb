require "spec_helper"
require "tempfile"

# Real dispatch coverage for the entity-query "ONE PARENT, NOT EVERY
# PARENT" fix: an entity query declaring `reference_to <ItsOwnAggregate>`
# finds the one named parent record directly, rather than flat-mapping
# every parent's own list and filtering afterward.
#
# Aggregate/entity names deliberately unique across this whole suite
# (not "Item"/"PersonalList") -- generic fixture names have caused real,
# order-dependent collisions elsewhere in this corpus (see dsl_spec.rb's
# own comment on the "Widget" collision it hit and fixed the same way).
RSpec.describe "an entity query scoped to its own named parent" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["scoped-parents-growth-", ".bluebook"])
    file.write(source)
    file.flush

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
    file&.close!
  end

  SOURCE = <<~BLUEBOOK
    Hecks.bluebook "ScopedParentsGrowth" do
      aggregate "GrowthRoster" do
        identified_by { id.value }

        value_object "GrowthRosterId" do
          attribute :value, String
        end

        attribute :id,      GrowthRosterId
        attribute :entries, list_of(GrowthEntry)

        entity "GrowthEntry" do
          identified_by { entry_id.value }

          attribute :entry_id, String

          query "OnRoster" do
            reference_to GrowthRoster
          end
        end

        command "Open" do
          attribute :id, GrowthRosterId
          emits "Opened"
        end

        command "AddEntry" do
          reference_to GrowthRoster
          attribute :entry_id, String
          then_set :entries, append: { entry_id: :entry_id }
          emits "EntryAdded"
        end
      end
    end
  BLUEBOOK

  def boot_rosters
    boot(SOURCE, "ScopedParentsGrowth") { ::ScopedParentsGrowth::GrowthRoster.persisted_by("Memory") }
  end

  it "finds only the named parent's own entries, not every roster's" do
    runtime = boot_rosters
    runtime.dispatch("ScopedParentsGrowth::GrowthRoster.Open", id: { value: "roster1" })
    runtime.dispatch("ScopedParentsGrowth::GrowthRoster.Open", id: { value: "roster2" })
    runtime.dispatch("ScopedParentsGrowth::GrowthRoster.AddEntry", id: "roster1", entry_id: "a")
    runtime.dispatch("ScopedParentsGrowth::GrowthRoster.AddEntry", id: "roster2", entry_id: "b")

    rows = runtime.query("ScopedParentsGrowth::GrowthRoster.GrowthEntry.OnRoster", growth_roster_id: "roster1")

    expect(rows.map { |row| row[:entry_id] }).to eq(["a"])
  end
end
