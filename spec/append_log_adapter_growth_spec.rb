require "spec_helper"
require "tempfile"
require "tmpdir"

# Real coverage for the AppendLog adapter: an alias onto Heki's own
# already-append-only Journal module, registered as its own .adapter/
# .port pair (persistence) for domains that want an explicitly
# append-only backend by name (event_sourcing.hecksagon's "each
# Event.Append save persists ONE immutable record to this process's
# private shard"). A real adapter, not a stub -- dispatching through it
# actually writes a .heki file to disk, the same storage Heki itself uses.
RSpec.describe "the AppendLog persistence adapter" do
  APPEND_LOG_ADAPTER = File.join(InMemoryDomain::ROOT, "lib/hecksagain/adapters/driven/append_log.adapter")

  def boot(source, hecksagon_name, dir:)
    file = Tempfile.new(["append-log-growth-", ".bluebook"])
    file.write(source)
    file.flush

    previous = ENV["HECKSAGAIN_META_VALIDATION"]
    ENV["HECKSAGAIN_META_VALIDATION"] = "off"

    registry = Hecksagain::Runtime::Registry.new
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(APPEND_LOG_ADAPTER)
      Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
      Hecks.hecksagon(hecksagon_name) { ::AppendLogGrowth::LedgerLine.persisted_by("AppendLog") }
      Hecks.world(hecksagon_name) { persisted_by("AppendLog") { dir dir } }
    end

    registry.verify!
    Hecksagain::Runtime::Loader.bind_runtime(
      Hecksagain::Runtime::Dispatcher.new(registry)
    )
  ensure
    ENV["HECKSAGAIN_META_VALIDATION"] = previous
    file&.close!
  end

  APPEND_LOG_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "AppendLogGrowth" do
      aggregate "LedgerLine" do
        identified_by { line_id.value }

        value_object "LineId" do
          attribute :value, String
        end

        attribute :line_id, LineId

        command "Record" do
          attribute :line_id, LineId
          emits "LineRecorded"
        end
      end
    end
  BLUEBOOK

  it "resolves as a real adapter (not a stub) and its wiring is satisfied" do
    Dir.mktmpdir do |dir|
      runtime = boot(APPEND_LOG_SOURCE, "AppendLogGrowth", dir: dir)

      expect(runtime.registry.adapter_class("AppendLog")).to eq(Hecksagain::Adapters::Heki)
    end
  end

  it "actually persists a real .heki file on disk, proving it is not a no-op stub" do
    Dir.mktmpdir do |dir|
      runtime = boot(APPEND_LOG_SOURCE, "AppendLogGrowth", dir: dir)

      runtime.dispatch("AppendLogGrowth::LedgerLine.Record", line_id: { value: "line-1" })

      heki_path = File.join(dir, "ledger_line.heki")
      expect(File.exist?(heki_path)).to be(true)

      bluebook = runtime.registry.bluebook("AppendLogGrowth")
      aggregate = bluebook.aggregate("LedgerLine")
      instance = runtime.registry.repository("AppendLogGrowth", aggregate).find("line-1")
      expect(instance).not_to be_nil
    end
  end
end
