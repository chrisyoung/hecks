require "spec_helper"

# ASKS AND TELLS — the two directions through one door.
#
# `tells` is what this language always had, spelled `operation`: an external
# fact arriving, turned into a domain event. `asks` is the direction it did
# not have — the domain wanting something from outside and having to live
# with either answer.
#
# Before this, a domain could be CALLED by an adapter and never call one.
# `Ports::Extraction.adapter.canonical(...)` is library code reaching for an
# adapter; `MockStripeAdapter#create_session` is an application doing the
# same. Neither is the domain asking, and neither leaves a trace in the
# record.
RSpec.describe "asks and tells" do
  # An adapter that answers, and one that does not. Both declare the same
  # port, so a boot picks whichever was loaded — which is how the refusal
  # path gets exercised without a network.
  class FakeIssueTracker
    def file(**args)
      { "number" => 43, "url" => "https://example.com/issues/43", "sent" => args[:title] }
    end
  end

  class BrokenIssueTracker
    def file(**) = raise IOError, "the token expired"
  end

  def boot(adapter_class)
    registry = Hecksagain::Runtime::Registry.new

    Hecksagain.with_registry(registry) do
      Kernel.load(InMemoryDomain::PERSISTENCE_PORT)
      Kernel.load(InMemoryDomain::EXTRACTION_PORT)
      Kernel.load(InMemoryDomain::MEMORY_ADAPTER)
      Kernel.load(InMemoryDomain::PRISM_ADAPTER)

      Hecksagain::Adapters.send(:remove_const, :Tracker) if Hecksagain::Adapters.const_defined?(:Tracker, false)
      Hecksagain::Adapters.const_set(:Tracker, adapter_class)
      Hecks.adapter("Tracker") { port "IssueTracker" }

      Hecks.bluebook "Asking" do
        aggregate "Ticket" do
          identified_by { reference.value }
          attribute :reference, TicketReference
          attribute :title,     TicketTitle

          value_object "TicketReference" do
            attribute :value, String
            invariant("a ticket is referenced") { !value.to_s.empty? }
          end

          value_object "TicketTitle" do
            attribute :value, String
            invariant("a ticket is titled") { !value.to_s.empty? }
          end

          command "Draft" do
            role "Reporter"
            goal "Write down what the outside world will be told"
            attribute :reference, TicketReference
            attribute :title,     TicketTitle
            emits "TicketDrafted"
          end

          # THE ASK IS DRIVEN OFF THIS ONE, NOT OFF `Draft`, AND THE REASON
          # IS THE PAYLOAD. A policy re-enters with the event payload
          # verbatim: a CREATING command emits its value objects
          # (`reference` => a TicketReference), while a non-creating one
          # emits `{ id: "TK-1" }`. A reference slot takes an id and
          # deliberately refuses an object, so only the second shape fits.
          command "Submit" do
            role "Reporter"
            goal "Send it"
            reference_to Ticket
            emits "TicketSubmitted"
          end
        end

        # A POLICY DRIVES THE ASK. No new reaction word was needed: the
        # dispatcher already resolves `Domain::Aggregate.Port.Operation` and
        # checks ports before entities, so `trigger` reaches an operation the
        # same way it reaches a command.
        policy "FileOnDraft" do
          on      "Ticket.TicketSubmitted"
          trigger "Ticket.IssueTracker.File"
        end
      end

      Hecks.hecksagon "Asking" do
        ::Asking::Ticket.persisted_by("Memory")

        ::Asking::Ticket.port "IssueTracker" do
          asks "File" do
            reference_to Ticket, as: :id
            answers "IssueFiled"
            refuses "IssueFilingFailed"
          end

          tells "Closed" do
            reference_to Ticket, as: :id
            emits "IssueClosedUpstream"
          end
        end
      end
    end

    registry.verify!
    Hecksagain::Runtime::Dispatcher.new(registry)
  end

  describe "the shape" do
    it "carries both directions on one port" do
      runtime = boot(FakeIssueTracker)
      port    = runtime.registry.bluebook("Asking").aggregate("Ticket").port("IssueTracker")

      expect(port.operation("File")).to be_outbound
      expect(port.operation("Closed")).to be_inbound
    end

    it "names both endings of an ask" do
      runtime = boot(FakeIssueTracker)
      file    = runtime.registry.bluebook("Asking").aggregate("Ticket").port("IssueTracker").operation("File")

      expect(file.answers).to eq("IssueFiled")
      expect(file.refuses).to eq("IssueFilingFailed")
    end
  end

  # EACH DIRECTION REFUSES THE OTHER'S WORDS.
  describe "what a chapter may not say" do
    def declaring(&block)
      -> { Hecksagain::Bluebook::DSL::DomainPortBuilder.build("Bad", &block) }
    end

    it "refuses an ask that emits instead of answering" do
      expect(&declaring { asks("X") { emits "Y" } })
        .to raise_error(Hecksagain::Bluebook::DSL::Malformed, /answers and refuses instead/)
    end

    it "refuses an ask that names no failure — a call into a system you do not control" do
      expect(&declaring { asks("X") { answers "Y" } })
        .to raise_error(Hecksagain::Bluebook::DSL::Malformed, /declares no refuses/)
    end

    it "refuses a tells that answers, because there is no channel back" do
      expect(&declaring { tells("X") { answers "Y" } })
        .to raise_error(Hecksagain::Bluebook::DSL::Malformed, /no channel back/)
    end
  end

  describe "asking, for real" do
    it "calls the bound adapter and announces what came back" do
      runtime = boot(FakeIssueTracker)
      runtime.dispatch("Asking::Ticket.Draft", reference: { value: "TK-1" }, title: { value: "an array in: never matches" })
      runtime.dispatch("Asking::Ticket.Submit", id: "TK-1")

      filed = runtime.events.find { |event| event.name == "IssueFiled" }
      expect(filed).not_to be_nil
      expect(filed.id).to eq("TK-1")
      # SPREAD, NOT NESTED — the adapter's own keys become the payload, which
      # is what lets a policy re-enter a command with them.
      expect(filed.payload[:number]).to eq(43)
      expect(filed.payload[:url]).to eq("https://example.com/issues/43")
    end

    # A RAISE FROM THE FAR SIDE IS NOT AN EXCEPTION IN THIS DOMAIN'S TERMS —
    # it is the outside saying no, and the chapter already named that word.
    it "turns a failure into the refusal the chapter named, not a crash" do
      runtime = boot(BrokenIssueTracker)

      expect {
        runtime.dispatch("Asking::Ticket.Draft", reference: { value: "TK-2" }, title: { value: "x" })
        runtime.dispatch("Asking::Ticket.Submit", id: "TK-2")
      }.not_to raise_error

      refused = runtime.events.find { |event| event.name == "IssueFilingFailed" }
      expect(refused.id).to eq("TK-2")
      expect(refused.payload[:refusal][:value]).to include("the token expired")
    end

    it "leaves the drafting command's own event intact either way" do
      runtime = boot(BrokenIssueTracker)
      runtime.dispatch("Asking::Ticket.Draft", reference: { value: "TK-3" }, title: { value: "x" })
      runtime.dispatch("Asking::Ticket.Submit", id: "TK-3")

      expect(runtime.events.map(&:name)).to start_with("TicketDrafted")
    end
  end

  describe "telling, unchanged" do
    it "still translates an inbound fact into a domain event" do
      runtime = boot(FakeIssueTracker)
      runtime.dispatch("Asking::Ticket.Draft", reference: { value: "TK-4" }, title: { value: "x" })
      runtime.dispatch("Asking::Ticket.IssueTracker.Closed", id: "TK-4")

      expect(runtime.events.map(&:name)).to include("IssueClosedUpstream")
    end
  end
end
