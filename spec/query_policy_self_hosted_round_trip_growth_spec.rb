require "spec_helper"
require "tempfile"

# Real coverage for Query's count/median/group_by and Policy's
# where/with/for_each self-hosted grammar round-trip: every Hecks.bluebook
# load runs MetaValidator.call, which dispatches the built IR into the
# language's own self-hosted meta-domain and replaces it with what THAT
# domain reconstructs. Before this fix, Query's count/median_field/
# group_by_field and Policy's wheres/with_literals/for_each all survived
# the DSL parse and vanished the moment a bluebook was actually loaded
# (meta-validation ON, the ordinary path -- no ENV escape hatch needed
# here, unlike items 06a/06b/06/08/09's own coverage).
RSpec.describe "Query/Policy self-hosted grammar round-trip" do
  def build(source)
    file = Tempfile.new(["query-policy-round-trip-growth-", ".bluebook"])
    file.write(source)
    file.flush

    registry = Hecksagain::Runtime::Registry.new
    bluebook = nil
    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)
      bluebook = Kernel.eval(source, TOPLEVEL_BINDING, file.path, 1)
    end
    bluebook
  ensure
    file&.close!
  end

  it "a query's count/median_field/group_by_field survive the Judge round-trip" do
    source = <<~BLUEBOOK
      Hecks.bluebook "QueryScalarsRoundTripGrowth" do
        aggregate "Ticket" do
          identified_by { id.value }
          value_object "TicketId" do
            attribute :value, String
          end
          attribute :id, TicketId
          attribute :priority, Integer

          command "Open" do
            attribute :id, TicketId
            attribute :priority, Integer
            emits "Opened"
          end

          query "Tally" do
            count
          end

          query "MidPriority" do
            median :priority
          end

          query "ByPriority" do
            group_by :priority
          end
        end
      end
    BLUEBOOK

    bluebook = build(source)
    ticket = bluebook.aggregate("Ticket")
    expect(ticket.query("Tally").count).to be(true)
    expect(ticket.query("MidPriority").median_field).to eq(:priority)
    expect(ticket.query("ByPriority").group_by_field).to eq(:priority)
  end

  it "a policy's where/with survive the Judge round-trip" do
    source = <<~BLUEBOOK
      Hecks.bluebook "PolicyMapsRoundTripGrowth" do
        aggregate "Ticket" do
          identified_by { id.value }
          value_object "TicketId" do
            attribute :value, String
          end
          attribute :id,       TicketId
          attribute :severity, String, default: "normal"

          command "Open" do
            attribute :id,       TicketId
            attribute :severity, String
            emits "Opened"
          end

          command "Escalate" do
            reference_to Ticket
            emits "Escalated"
          end

          policy "EscalateOnCritical" do
            on      "Opened"
            where   severity: "critical"
            with    "note", "auto-flagged"
            trigger "Ticket.Escalate"
          end
        end
      end
    BLUEBOOK

    bluebook = build(source)
    policy = bluebook.policies.find { |p| p.name == "EscalateOnCritical" }
    expect(policy.wheres).to eq(severity: "critical")
    expect(policy.with_literals).to eq("note" => "auto-flagged")
  end

  it "a policy's for_each (compound from:/where:) survives the Judge round-trip" do
    source = <<~BLUEBOOK
      Hecks.bluebook "PolicyForEachRoundTripGrowth" do
        aggregate "Ticket" do
          identified_by { id.value }
          value_object "TicketId" do
            attribute :value, String
          end
          attribute :id,    TicketId
          attribute :board, String

          command "Open" do
            attribute :id,    TicketId
            attribute :board, String
            emits "Opened"
          end

          command "Ping" do
            reference_to Ticket
            emits "Pinged"
          end

          query "ForBoard" do
            attribute :board, String
            where board: :board
          end
        end

        aggregate "Board" do
          identified_by { id.value }
          value_object "BoardId" do
            attribute :value, String
          end
          attribute :id, BoardId

          command "Sweep" do
            attribute :id, BoardId
            emits "Swept"
          end

          policy "PingOnSweep" do
            on       "Swept"
            for_each from: "Ticket.ForBoard", where: { board: from_event(:id) }
            trigger  "Ticket.Ping"
          end
        end
      end
    BLUEBOOK

    bluebook = build(source)
    policy = bluebook.policies.find { |p| p.name == "PingOnSweep" }
    expect(policy.for_each_from).to eq("Ticket.ForBoard")
    expect(policy.for_each_where).to eq(board: :id)
  end
end
