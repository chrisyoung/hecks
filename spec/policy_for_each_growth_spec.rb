require "spec_helper"
require "tempfile"

# Real coverage for policy `for_each from:, where:` + `from_event` --
# finding #12: a policy-level fan-out, the same shape as `dispatch ...,
# for_each:` already built for saga handlers.
#
# The DSL side alone (`PolicyBuilder.build`) needs no boot at all, and
# proves the BUILDER half of this PR parses `for_each`/`from_event` into
# the shape `PolicyInterpreter#deliver_for_each` reads, independent of
# whether a real dispatch can reach that shape at all.
#
# A REAL dispatch finds two further, separate, genuine runtime gaps,
# both fixed by a later-landing item in this split:
# `PolicyInterpreter#deliver_for_each` hands `QueryInterpreter#call` the
# bare aggregate NAME it split out of `from:`, never resolved to the
# aggregate object `#call` needs (`Dispatcher#resolve_aggregate` always
# does this resolution first for an ordinary query) -- that alone raises
# a plain `NoMethodError: undefined method 'query' for a String`. But
# `deliver`'s own `return deliver_for_each(...) if policy.for_each` runs
# BEFORE `record` (the reaction-log entry both of `deliver`'s own rescue
# clauses call `.merge` on) is assigned, so the SAME method's own defect
# handling then raises a SECOND, different `NoMethodError: undefined
# method 'merge' for nil` trying to record the first one -- the one this
# example actually observes and pins, since Ruby's own exception-in-
# rescue replaces the original. Pinned here as the current, real
# behaviour -- the later fix should turn this red, which is the point:
# it is the signal to replace this example with the positive one (one
# dispatch per matching row) this construct is actually meant to prove.
RSpec.describe "a policy's own for_each fan-out" do
  def boot(source, hecksagon_name, &binds)
    file = Tempfile.new(["policy-for-each-growth-", ".bluebook"])
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

  it "parses for_each + from_event into the fan-out shape the interpreter reads" do
    policy = Hecksagain::Bluebook::DSL::PolicyBuilder.build("PingGrowthTicketsOnOpen") do
      on "Opened"
      for_each from: "GrowthTicket.ForBoard", where: { board_id: from_event(:id) }
      trigger "GrowthTicket.Ping"
    end

    expect(policy.for_each).to eq(from: "GrowthTicket.ForBoard", where: { board_id: :id })
  end

  FOR_EACH_SOURCE = <<~BLUEBOOK
    Hecks.bluebook "FanoutGrowth" do
      aggregate "GrowthBoard" do
        identified_by { id.value }

        value_object "GrowthBoardId" do
          attribute :value, String
        end

        attribute :id, GrowthBoardId

        command "Open" do
          attribute :id, GrowthBoardId
          emits "Opened"
        end
      end

      aggregate "GrowthTicket" do
        identified_by { id.value }

        value_object "GrowthTicketId" do
          attribute :value, String
        end

        attribute :id,       GrowthTicketId
        attribute :board_id, String
        attribute :status,   String, default: "open"

        command "Create" do
          attribute :id,       GrowthTicketId
          attribute :board_id, String
          emits "Created"
        end

        command "Ping" do
          reference_to GrowthTicket
          then_set :status, to: "pinged"
        end

        query "ForBoard" do
          attribute :board_id, String
          where board_id: :board_id
        end
      end

      policy "PingGrowthTicketsOnOpen" do
        on "Opened"
        for_each from: "GrowthTicket.ForBoard", where: { board_id: from_event(:id) }
        trigger "GrowthTicket.Ping"
      end
    end
  BLUEBOOK

  it "currently crashes on dispatch -- deliver_for_each never resolves the aggregate it queries" do
    runtime = boot(FOR_EACH_SOURCE, "FanoutGrowth") do
      ::FanoutGrowth::GrowthBoard.persisted_by("Memory")
      ::FanoutGrowth::GrowthTicket.persisted_by("Memory")
    end
    runtime.dispatch("FanoutGrowth::GrowthTicket.Create", id: { value: "t1" }, board_id: "b1")

    expect { runtime.dispatch("FanoutGrowth::GrowthBoard.Open", id: { value: "b1" }) }
      .to raise_error(NoMethodError, /undefined method [`']merge['`]? for nil/)
  end
end
