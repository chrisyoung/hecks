require "spec_helper"

RSpec.describe "Lifecycle DSL" do
  let(:domain) do
    Hecks.domain "Workflow" do
      aggregate "Ticket" do
        attribute :title, String
        attribute :status, String

        lifecycle :status, default: "open" do
          transition "CreateTicket" => "open"
          transition "StartTicket"  => "in_progress"
          transition "CloseTicket"  => "closed"
        end

        command "CreateTicket" do
          attribute :title, String
        end

        command "StartTicket" do
          attribute :ticket_id, String
        end

        command "CloseTicket" do
          attribute :ticket_id, String
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  describe "DSL" do
    it "stores lifecycle on aggregate IR" do
      agg = domain.aggregates.first
      expect(agg.lifecycle).not_to be_nil
      expect(agg.lifecycle.field).to eq(:status)
      expect(agg.lifecycle.default).to eq("open")
    end

    it "stores transitions" do
      agg = domain.aggregates.first
      expect(agg.lifecycle.target_for("CloseTicket")).to eq("closed")
      expect(agg.lifecycle.states).to include("open", "in_progress", "closed")
    end
  end

  describe "generated commands" do
    it "sets default status on create" do
      ticket = Ticket.create(title: "Fix bug")
      expect(ticket.status).to eq("open")
    end

    it "transitions status on update commands" do
      ticket = Ticket.create(title: "Fix bug")
      Ticket.start(ticket_id: ticket.id)
      updated = Ticket.find(ticket.id)
      expect(updated.status).to eq("in_progress")
    end

    it "transitions through multiple states" do
      ticket = Ticket.create(title: "Fix bug")
      Ticket.start(ticket_id: ticket.id)
      Ticket.close(ticket_id: ticket.id)
      final = Ticket.find(ticket.id)
      expect(final.status).to eq("closed")
    end
  end

  describe "status predicates" do
    it "generates predicate methods for each state" do
      ticket = Ticket.create(title: "Test")
      expect(ticket.open?).to be true
      expect(ticket.in_progress?).to be false
      expect(ticket.closed?).to be false
    end
  end
end
