require "spec_helper"
require "tempfile"

# Real dispatch coverage for `count` -- a scalar row-count ask, riding
# the same where-clauses an ordinary query already applies.
#
# `meta_validation: false` for the same reason as this split's group_by
# coverage -- the self-hosted grammar doesn't carry Query's `count`
# through its own Judge round-trip yet.
RSpec.describe "a query's own count" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["count-growth-", ".bluebook"])
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

  COUNT_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "TallyGrowth" do
      aggregate "Ticket" do
        identified_by { id.value }

        value_object "TicketId" do
          attribute :value, String
        end

        attribute :id,     TicketId
        attribute :status, String, default: "open"

        command "Open" do
          attribute :id, TicketId
          emits "Opened"
        end

        command "Close" do
          reference_to Ticket
          then_set :status, to: "closed"
        end

        query "OpenCount" do
          where(status: "open")
          count
        end
      end
    end
  BLUEBOOK

  def boot_tally
    boot(COUNT_SOURCE, "TallyGrowth") { ::TallyGrowth::Ticket.persisted_by("Memory") }
  end

  it "counts the where-filtered set, not the whole table" do
    runtime = boot_tally
    runtime.dispatch("TallyGrowth::Ticket.Open", id: { value: "t1" })
    runtime.dispatch("TallyGrowth::Ticket.Open", id: { value: "t2" })
    runtime.dispatch("TallyGrowth::Ticket.Open", id: { value: "t3" })
    runtime.dispatch("TallyGrowth::Ticket.Close", id: "t3")

    expect(runtime.query("TallyGrowth::Ticket.OpenCount")).to eq(2)
  end
end
