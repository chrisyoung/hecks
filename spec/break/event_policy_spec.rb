require "spec_helper"
require "tmpdir"
require "timeout"

RSpec.describe "Event bus and policy edge cases (destructive)" do
  def BreakTestDomains.boot(domain)
    tmpdir = Dir.mktmpdir("hecks_break_test")
    gem_path = Hecks.build(domain, output_dir: tmpdir)
    lib_path = File.join(gem_path, "lib")
    $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
    load File.join(lib_path, "#{domain.gem_name}.rb")
    Dir[File.join(lib_path, "**/*.rb")].sort.each { |f| load f }
    Hecks::Services::Application.new(domain)
  end

  # ---------------------------------------------------------------------------
  # BUG 1: Self-triggering policy causes SystemStackError (infinite recursion)
  #
  # PlaceOrder -> PlacedOrder -> policy triggers PlaceOrder -> PlacedOrder -> ...
  # The framework has no recursion depth guard.
  # ---------------------------------------------------------------------------
  describe "BUG: policy that triggers itself (infinite loop)" do
    let(:domain) do
      Hecks.domain "Loop" do
        aggregate "Ticket" do
          attribute :title, String

          command "CreateTicket" do
            attribute :title, String
          end

          command "EscalateTicket" do
            attribute :title, String
          end

          # EscalatedTicket triggers EscalateTicket again -- infinite loop
          policy "SelfEscalate" do
            on "EscalatedTicket"
            trigger "EscalateTicket"
          end
        end
      end
    end

    it "does not hang or blow the stack on a self-triggering policy" do
      app = BreakTestDomains.boot(domain)

      result = Timeout.timeout(3) do
        begin
          app.run("EscalateTicket", title: "help")
        rescue SystemStackError, StandardError => e
          e
        end
      end

      # We got here without hanging -- that is the main assertion.
      # If we got a SystemStackError that is a bug (no recursion guard).
      expect(result).not_to be_a(SystemStackError),
        "Self-triggering policy caused SystemStackError (infinite recursion). " \
        "The framework needs a recursion depth guard in setup_policies or EventBus."
    end
  end

  # ---------------------------------------------------------------------------
  # BUG 2: Past-tense verb inflection is broken for irregular verbs
  #
  # The Command#inferred_event_name method only handles two cases:
  #   - ends with 'e' -> add 'd'
  #   - everything else -> add 'ed'
  #
  # This produces wrong results for:
  #   - consonant+y: "Notify" -> "Notifyed" (should be "Notified")
  #   - irregular: "Send" -> "Sended" (should be "Sent")
  #
  # See lib/hecks/domain_model/behavior/command.rb lines 31-35
  # ---------------------------------------------------------------------------
  describe "BUG: past-tense inflection for irregular verbs" do
    let(:domain) do
      Hecks.domain "Inflect" do
        aggregate "Alert" do
          attribute :message, String

          command "NotifyAlert" do
            attribute :message, String
          end

          command "SendAlert" do
            attribute :message, String
          end
        end
      end
    end

    it "inflects 'Notify' as 'Notified', not 'Notifyed'" do
      app = BreakTestDomains.boot(domain)
      app.run("NotifyAlert", message: "test")

      event_name = app.events.first.class.name.split("::").last

      expect(event_name).to eq("NotifiedAlert"),
        "Expected event name 'NotifiedAlert' but got '#{event_name}'. " \
        "Command#inferred_event_name does not handle consonant+y -> ied."
    end

    it "inflects 'Send' as 'Sent', not 'Sended'" do
      app = BreakTestDomains.boot(domain)
      app.run("SendAlert", message: "test")

      event_name = app.events.last.class.name.split("::").last

      expect(event_name).to eq("SentAlert"),
        "Expected event name 'SentAlert' but got '#{event_name}'. " \
        "Command#inferred_event_name does not handle irregular verbs."
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Two policies on the same event
  #
  # Both should fire when the triggering event is published. We use verbs
  # with correct inflection (Create -> Created) to isolate the policy test.
  # ---------------------------------------------------------------------------
  describe "two policies on the same event" do
    let(:domain) do
      Hecks.domain "Multi" do
        aggregate "Invoice" do
          attribute :amount, Integer
          attribute :status, String

          command "CreateInvoice" do
            attribute :amount, Integer
          end

          command "UpdateAccounting" do
            attribute :amount, Integer
          end

          command "UpdateShipping" do
            attribute :amount, Integer
          end

          policy "AccountingNotification" do
            on "CreatedInvoice"
            trigger "UpdateAccounting"
          end

          policy "ShippingNotification" do
            on "CreatedInvoice"
            trigger "UpdateShipping"
          end
        end
      end
    end

    it "fires both policies when a single event is published" do
      app = BreakTestDomains.boot(domain)
      app.run("CreateInvoice", amount: 100)

      event_names = app.events.map { |e| e.class.name.split("::").last }

      expect(event_names).to include("CreatedInvoice")
      expect(event_names).to include("UpdatedAccounting"),
        "Accounting policy did not fire. Only got: #{event_names}"
      expect(event_names).to include("UpdatedShipping"),
        "Shipping policy did not fire. Only got: #{event_names}"
      expect(event_names.count("UpdatedAccounting")).to eq(1)
      expect(event_names.count("UpdatedShipping")).to eq(1)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Policy triggers a command that doesn't exist
  #
  # Hecks validates at build time, which is correct behavior. This test
  # confirms that validation catches it with a clear error message.
  # ---------------------------------------------------------------------------
  describe "policy triggers nonexistent command" do
    it "raises a validation error at build time with a clear message" do
      domain = Hecks.domain "Ghost" do
        aggregate "Widget" do
          attribute :name, String

          command "CreateWidget" do
            attribute :name, String
          end

          policy "BrokenPolicy" do
            on "CreatedWidget"
            trigger "GhostCommand"
          end
        end
      end

      expect {
        BreakTestDomains.boot(domain)
      }.to raise_error(RuntimeError, /GhostCommand/)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Subscribe to an event, create 100 items, verify all 100 events received
  # ---------------------------------------------------------------------------
  describe "high-volume event delivery" do
    let(:domain) do
      Hecks.domain "Volume" do
        aggregate "Item" do
          attribute :name, String

          command "CreateItem" do
            attribute :name, String
          end
        end
      end
    end

    it "delivers all 100 events to subscribers without dropping any" do
      app = BreakTestDomains.boot(domain)

      received = []
      app.on("CreatedItem") { |event| received << event }

      100.times { |i| app.run("CreateItem", name: "item_#{i}") }

      expect(received.size).to eq(100),
        "Expected 100 events, got #{received.size}. Events are being dropped."
      expect(app.events.size).to eq(100),
        "Expected 100 events in the log, got #{app.events.size}."

      names = received.map(&:name)
      100.times { |i| expect(names).to include("item_#{i}") }
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Clear events then verify empty
  # ---------------------------------------------------------------------------
  describe "event bus clear" do
    let(:domain) do
      Hecks.domain "Clearable" do
        aggregate "Thing" do
          attribute :label, String

          command "CreateThing" do
            attribute :label, String
          end
        end
      end
    end

    it "empties the event log after clear" do
      app = BreakTestDomains.boot(domain)

      5.times { |i| app.run("CreateThing", label: "thing_#{i}") }
      expect(app.events.size).to eq(5)

      app.event_bus.clear
      expect(app.events).to be_empty
      expect(app.events.size).to eq(0)
    end

    it "continues recording events after clear" do
      app = BreakTestDomains.boot(domain)

      3.times { |i| app.run("CreateThing", label: "before_#{i}") }
      app.event_bus.clear

      2.times { |i| app.run("CreateThing", label: "after_#{i}") }
      expect(app.events.size).to eq(2)
      expect(app.events.map(&:label)).to eq(["after_0", "after_1"])
    end

    it "does not affect subscribers after clear" do
      app = BreakTestDomains.boot(domain)
      received = []
      app.on("CreatedThing") { |e| received << e }

      app.run("CreateThing", label: "first")
      app.event_bus.clear

      app.run("CreateThing", label: "second")
      expect(received.size).to eq(2),
        "Subscriber stopped receiving after clear. Got #{received.size} events."
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Event ordering -- are events in dispatch order?
  # ---------------------------------------------------------------------------
  describe "event ordering" do
    let(:domain) do
      Hecks.domain "Ordered" do
        aggregate "Step" do
          attribute :position, Integer

          command "CreateStep" do
            attribute :position, Integer
          end
        end
      end
    end

    it "records events in the order commands were dispatched" do
      app = BreakTestDomains.boot(domain)

      positions = (1..20).to_a
      positions.each { |p| app.run("CreateStep", position: p) }

      recorded_positions = app.events.map(&:position)
      expect(recorded_positions).to eq(positions),
        "Events are out of order! Expected #{positions}, got #{recorded_positions}"
    end

    it "subscriber receives events in dispatch order" do
      app = BreakTestDomains.boot(domain)
      received_positions = []
      app.on("CreatedStep") { |e| received_positions << e.position }

      (1..20).each { |p| app.run("CreateStep", position: p) }

      expect(received_positions).to eq((1..20).to_a),
        "Subscriber received events out of order: #{received_positions}"
    end
  end
end
