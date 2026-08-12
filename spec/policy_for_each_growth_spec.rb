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
# GAPS CLOSED (item 48, `c028843`): a real dispatch used to find two
# further, separate, genuine runtime gaps.
# `PolicyInterpreter#deliver_for_each` hands `QueryInterpreter#call` the
# bare aggregate NAME it split out of `from:`, never resolved to the
# aggregate object `#call` needs (`Dispatcher#resolve_aggregate` always
# does this resolution first for an ordinary query) -- that alone raised
# a plain `NoMethodError: undefined method 'query' for a String`. But
# `deliver`'s own `return deliver_for_each(...) if policy.for_each` ran
# BEFORE `record` (the reaction-log entry both of `deliver`'s own rescue
# clauses call `.merge` on) was assigned, so the SAME method's own defect
# handling then raised a SECOND, different `NoMethodError: undefined
# method 'merge' for nil` trying to record the first one. Both fixed at
# the root -- the examples below now prove the positive shape (one
# dispatch per matching row) this construct is actually meant to prove,
# plus the honest undelivered-reaction case for an unloaded target.
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

  # GAP CLOSED (item 48, `c028843`): a real dispatch now fires one trigger
  # per matching row, exactly the shape `for_each` is meant to prove --
  # `deliver_for_each` resolves the aggregate it queries and `deliver`
  # itself computes `record` before branching to it.
  it "fires the triggered command once per matching row, real dispatch end to end" do
    runtime = boot(FOR_EACH_SOURCE, "FanoutGrowth") do
      ::FanoutGrowth::GrowthBoard.persisted_by("Memory")
      ::FanoutGrowth::GrowthTicket.persisted_by("Memory")
    end
    runtime.dispatch("FanoutGrowth::GrowthTicket.Create", id: { value: "t1" }, board_id: "b1")
    runtime.dispatch("FanoutGrowth::GrowthTicket.Create", id: { value: "t2" }, board_id: "b1")
    # a different board's own ticket must NOT be pinged
    runtime.dispatch("FanoutGrowth::GrowthTicket.Create", id: { value: "t3" }, board_id: "b2")

    runtime.dispatch("FanoutGrowth::GrowthBoard.Open", id: { value: "b1" })

    statuses = %w[t1 t2 t3].to_h do |id|
      status = runtime.registry.repository("FanoutGrowth", runtime.registry.bluebook("FanoutGrowth").aggregate("GrowthTicket")).find(id).state[:status]
      [id, status.respond_to?(:to_h) ? status.to_h[:value] : status]
    end
    expect(statuses).to eq("t1" => "pinged", "t2" => "pinged", "t3" => "open")
  end

  it "an unloaded for_each aggregate is recorded as an undelivered reaction, not a crash" do
    source = FOR_EACH_SOURCE.sub('for_each from: "GrowthTicket.ForBoard"', 'for_each from: "GhostAggregate.ForBoard"')
    runtime = boot(source, "FanoutGrowth") do
      ::FanoutGrowth::GrowthBoard.persisted_by("Memory")
      ::FanoutGrowth::GrowthTicket.persisted_by("Memory")
    end

    expect { runtime.dispatch("FanoutGrowth::GrowthBoard.Open", id: { value: "b1" }) }.not_to raise_error

    entry = runtime.registry.reaction_log.find { |row| row[:policy] == "PingGrowthTicketsOnOpen" }
    expect(entry[:delivered]).to be(false)
  end
end
