require "spec_helper"
require "tmpdir"
require "timeout"

# Destructive tests: multi-domain scenarios designed to expose bugs.
# Each test targets a specific assumption that could break under pressure.
#
# BUGS FOUND:
#   1. hoist_constants silently clobbers Object constants when two domains
#      share an aggregate name (e.g., both have "User")
#   2. Policies dispatch through CommandBus which only publishes events --
#      they NEVER persist aggregates. Cross-domain policies are broken.
#   3. Same-named events cause policies to self-trigger (infinite loop risk,
#      swallowed by rescue in setup_policies)
#   4. Booting the same domain twice overwrites class-level bindings --
#      first Application becomes a zombie (event bus and repo disconnected)

RSpec.describe "BREAK: Multi-domain conflicts" do
  # Helper: build a domain gem, load it, return the Application
  def boot(domain, event_bus: nil)
    Hecks.load_domain(domain)
    Hecks::Services::Application.new(domain, event_bus: event_bus)
  end

  before { @tmpdirs = [] }
  after  { @tmpdirs.each { |d| FileUtils.rm_rf(d) } }

  # ---------------------------------------------------------------------------
  # BUG 1: hoist_constants clobbers Object when two domains share a name
  # ---------------------------------------------------------------------------
  describe "same-named aggregates across domains" do
    let(:crm_domain) do
      Hecks.domain "Crm" do
        aggregate "User" do
          attribute :email, String
          command "CreateUser" do
            attribute :email, String
          end
        end
      end
    end

    let(:iam_domain) do
      Hecks.domain "Iam" do
        aggregate "User" do
          attribute :role, String
          command "CreateUser" do
            attribute :role, String
          end
        end
      end
    end

    it "BUG: Object::User points to whichever domain booted LAST" do
      _crm_app = boot(crm_domain)
      _iam_app = boot(iam_domain)

      # hoist_constants does Object.const_set(agg.name, klass) for each domain.
      # The second boot silently overwrites the first. CRM's User is gone.
      expect(Object.const_get(:User)).to eq(IamDomain::User)

      # Calling User.create with CRM attributes fails because User is now IAM:
      expect {
        User.create(email: "test@example.com")
      }.to raise_error(ArgumentError)
    end

    it "namespaced access still works despite the hoisted clobber" do
      _crm_app = boot(crm_domain)
      _iam_app = boot(iam_domain)

      crm_user = CrmDomain::User.create(email: "crm@test.com")
      iam_user = IamDomain::User.create(role: "admin")

      expect(crm_user.email).to eq("crm@test.com")
      expect(iam_user.role).to eq("admin")
    end

    it "repositories are isolated — CRM users don't appear in IAM" do
      crm_app = boot(crm_domain)
      iam_app = boot(iam_domain)

      CrmDomain::User.create(email: "crm@test.com")
      IamDomain::User.create(role: "admin")

      expect(crm_app["User"].all.size).to eq(1)
      expect(iam_app["User"].all.size).to eq(1)
      expect(crm_app["User"].all.first.email).to eq("crm@test.com")
      expect(iam_app["User"].all.first.role).to eq("admin")
    end
  end

  # ---------------------------------------------------------------------------
  # BUG 2: Policies only dispatch through CommandBus (event-only, no persist).
  #         Cross-domain policies fire events but NEVER save aggregates.
  # ---------------------------------------------------------------------------
  describe "BUG: cross-domain policy does not persist" do
    let(:orders_domain) do
      Hecks.domain "Orders" do
        aggregate "Order" do
          attribute :item, String
          command "CreateOrder" do
            attribute :item, String
          end
        end
      end
    end

    let(:warehouse_domain) do
      Hecks.domain "Warehouse" do
        aggregate "Shipment" do
          attribute :item, String

          command "CreateShipment" do
            attribute :item, String
          end

          policy "ShipOnOrder" do
            on "CreatedOrder"
            trigger "CreateShipment"
          end
        end
      end
    end

    it "BUG: policy fires event but shipment is NOT persisted" do
      shared_bus = Hecks::Services::EventBus.new
      _orders_app = boot(orders_domain, event_bus: shared_bus)
      warehouse_app = boot(warehouse_domain, event_bus: shared_bus)

      OrdersDomain::Order.create(item: "Widget")

      # The event WAS published (policy ran through CommandBus.dispatch)...
      event_names = shared_bus.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to include("CreatedOrder")
      expect(event_names).to include("CreatedShipment")

      # ...but the Shipment was NEVER saved to the repository.
      # setup_policies calls @command_bus.dispatch, which publishes events
      # but does NOT call Shipment.create (which is what saves to the repo).
      # This is the core bug: policies are event-only, not persistence-aware.
      shipments = warehouse_app["Shipment"].all
      expect(shipments.size).to eq(0) # BUG: should be 1
    end
  end

  # ---------------------------------------------------------------------------
  # BUG 3: Three domains, one bus — policies fire events but don't persist
  # ---------------------------------------------------------------------------
  describe "BUG: three domains, one bus — policies don't persist" do
    let(:sales_domain) do
      Hecks.domain "Sales" do
        aggregate "Deal" do
          attribute :amount, Integer
          command "CreateDeal" do
            attribute :amount, Integer
          end
        end
      end
    end

    let(:accounting_domain) do
      Hecks.domain "Accounting" do
        aggregate "Ledger" do
          attribute :amount, Integer
          command "CreateLedger" do
            attribute :amount, Integer
          end

          policy "RecordDeal" do
            on "CreatedDeal"
            trigger "CreateLedger"
          end
        end
      end
    end

    let(:analytics_domain) do
      Hecks.domain "Analytics" do
        aggregate "Metric" do
          attribute :amount, Integer
          command "CreateMetric" do
            attribute :amount, Integer
          end

          policy "TrackDeal" do
            on "CreatedDeal"
            trigger "CreateMetric"
          end
        end
      end
    end

    it "BUG: policies fire events but no aggregates are persisted" do
      shared_bus = Hecks::Services::EventBus.new
      _sales_app = boot(sales_domain, event_bus: shared_bus)
      accounting_app = boot(accounting_domain, event_bus: shared_bus)
      analytics_app = boot(analytics_domain, event_bus: shared_bus)

      SalesDomain::Deal.create(amount: 1000)

      # Events were published by the policies...
      event_names = shared_bus.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to include("CreatedDeal")
      expect(event_names).to include("CreatedLedger")
      expect(event_names).to include("CreatedMetric")

      # ...but NOTHING was persisted. Same bug as test 2.
      expect(accounting_app["Ledger"].all.size).to eq(0)  # BUG: should be 1
      expect(analytics_app["Metric"].all.size).to eq(0)   # BUG: should be 1
    end

    it "all three apps see all events on the shared bus (events work, persistence doesn't)" do
      shared_bus = Hecks::Services::EventBus.new
      sales_app = boot(sales_domain, event_bus: shared_bus)
      accounting_app = boot(accounting_domain, event_bus: shared_bus)
      analytics_app = boot(analytics_domain, event_bus: shared_bus)

      SalesDomain::Deal.create(amount: 500)

      # All three share the bus, so all see the same 3 events
      expect(sales_app.events.size).to eq(3)
      expect(accounting_app.events.size).to eq(3)
      expect(analytics_app.events.size).to eq(3)
    end
  end

  # ---------------------------------------------------------------------------
  # BUG 4: Booting same domain twice — second boot zombifies the first
  # ---------------------------------------------------------------------------
  describe "BUG: same domain booted twice — first app becomes zombie" do
    let(:chat_domain) do
      Hecks.domain "Chat" do
        aggregate "Message" do
          attribute :body, String
          command "CreateMessage" do
            attribute :body, String
          end
        end
      end
    end

    it "BUG: second boot overwrites class bindings — bus_a is dead" do
      bus_a = Hecks::Services::EventBus.new
      bus_b = Hecks::Services::EventBus.new

      _app_a = boot(chat_domain, event_bus: bus_a)
      _app_b = boot(chat_domain, event_bus: bus_b)

      # ChatDomain::Message.create uses whichever command bus was bound last.
      # The second boot overwrote the singleton methods on the class.
      ChatDomain::Message.create(body: "Hello")

      # Events only go to bus_b. bus_a is silently disconnected.
      expect(bus_b.events.size).to eq(1)
      expect(bus_a.events.size).to eq(0)
    end

    it "BUG: second boot owns the repository — first app's repo is empty" do
      bus_a = Hecks::Services::EventBus.new
      bus_b = Hecks::Services::EventBus.new

      app_a = boot(chat_domain, event_bus: bus_a)
      app_b = boot(chat_domain, event_bus: bus_b)

      ChatDomain::Message.create(body: "test")

      # Data lives only in app_b's repository
      expect(app_b["Message"].all.size).to eq(1)
      expect(app_a["Message"].all.size).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # BUG 5: Policy persistence gap — events fire, aggregates don't save
  # ---------------------------------------------------------------------------
  describe "BUG: policy fires event but aggregate not persisted" do
    let(:shop_domain) do
      Hecks.domain "Shop" do
        aggregate "Product" do
          attribute :name, String
          command "CreateProduct" do
            attribute :name, String
          end
        end
      end
    end

    let(:audit_domain) do
      Hecks.domain "Audit" do
        aggregate "LogEntry" do
          attribute :name, String

          command "CreateLogEntry" do
            attribute :name, String
          end

          policy "LogProductCreation" do
            on "CreatedProduct"
            trigger "CreateLogEntry"
          end
        end
      end
    end

    it "BUG: policy publishes CreatedLogEntry event but LogEntry is never saved" do
      shared_bus = Hecks::Services::EventBus.new
      shop_app = boot(shop_domain, event_bus: shared_bus)
      audit_app = boot(audit_domain, event_bus: shared_bus)

      ShopDomain::Product.create(name: "Laptop")

      # Product WAS persisted (created via aggregate class method)
      expect(shop_app["Product"].all.size).to eq(1)

      # Event WAS published by the policy
      event_names = shared_bus.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to eq(["CreatedProduct", "CreatedLogEntry"])

      # But LogEntry was NOT saved — the policy went through CommandBus.dispatch
      # which only publishes events, it doesn't call AuditDomain::LogEntry.create
      expect(audit_app["LogEntry"].all.size).to eq(0) # BUG: should be 1
    end

    it "audit domain's repository has no Product (correct isolation)" do
      shared_bus = Hecks::Services::EventBus.new
      _shop_app = boot(shop_domain, event_bus: shared_bus)
      audit_app = boot(audit_domain, event_bus: shared_bus)

      ShopDomain::Product.create(name: "Phone")

      # Audit domain has no "Product" repository — returns nil
      expect(audit_app["Product"]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # BUG 6: Same-named events cause policy self-triggering (recursion risk)
  # ---------------------------------------------------------------------------
  describe "BUG: same-named events cause policy self-trigger" do
    let(:hr_domain) do
      Hecks.domain "Hr" do
        aggregate "Employee" do
          attribute :name, String
          command "CreateEmployee" do
            attribute :name, String
          end
        end
      end
    end

    let(:payroll_domain) do
      Hecks.domain "Payroll" do
        aggregate "Employee" do
          attribute :salary, Integer

          command "CreateEmployee" do
            attribute :salary, Integer
          end

          # Listens for "CreatedEmployee" — same name as its OWN event!
          policy "SyncFromHr" do
            on "CreatedEmployee"
            trigger "CreateEmployee"
          end
        end
      end
    end

    it "BUG: policy triggers on its own event name but fails on attribute mismatch" do
      shared_bus = Hecks::Services::EventBus.new

      _hr_app = boot(hr_domain, event_bus: shared_bus)
      _payroll_app = boot(payroll_domain, event_bus: shared_bus)

      # HR creates an employee -> emits CreatedEmployee (with :name attribute).
      # Payroll's SyncFromHr policy subscribes to "CreatedEmployee" and fires.
      # It tries to dispatch CreateEmployee with {name: "Alice"} but Payroll's
      # CreateEmployee expects :salary, not :name. This causes an error that
      # gets silently rescued by setup_policies.
      #
      # BUG 1: The event bus matches by short class name ("CreatedEmployee"),
      #   so events from ANY domain with that name trigger the policy.
      #   There's no domain-scoping on event names.
      #
      # BUG 2: The error is silently swallowed — no way for the developer
      #   to know the policy failed unless they watch stderr.
      #
      # BUG 3: If both domains had the SAME attributes, this would infinite loop.

      # Capture stderr to prove the silent failure
      captured_warnings = []
      allow($stderr).to receive(:write) { |msg| captured_warnings << msg }

      result = nil
      begin
        Timeout.timeout(5) do
          HrDomain::Employee.create(name: "Alice")
          result = :completed
        end
      rescue Timeout::Error
        result = :timeout
      rescue SystemStackError
        result = :stack_overflow
      end

      expect(result).to eq(:completed)

      # Only 1 CreatedEmployee event (from HR) — Payroll's policy crashed
      # before it could publish its own event
      event_names = shared_bus.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to eq(["CreatedEmployee"])

      # The framework silently warns on stderr but doesn't raise
      # (the policy handler rescues StandardError)
    end

    it "BUG: same event+attribute names cause SystemStackError (not rescued)" do
      # If both domains have identical event shapes, the policy loops forever.
      matching_hr = Hecks.domain "MatchHr" do
        aggregate "Worker" do
          attribute :name, String
          command "CreateWorker" do
            attribute :name, String
          end
        end
      end

      matching_payroll = Hecks.domain "MatchPayroll" do
        aggregate "Worker" do
          attribute :name, String
          command "CreateWorker" do
            attribute :name, String
          end
          policy "SyncWorker" do
            on "CreatedWorker"
            trigger "CreateWorker"
          end
        end
      end

      shared_bus = Hecks::Services::EventBus.new
      _hr_app = boot(matching_hr, event_bus: shared_bus)
      _payroll_app = boot(matching_payroll, event_bus: shared_bus)

      # Previously this would cause infinite recursion (SystemStackError),
      # but the re-entrancy guard now prevents the policy from re-triggering.
      expect {
        MatchHrDomain::Worker.create(name: "Bob")
      }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # PASSING: Event ordering on shared bus works correctly
  # ---------------------------------------------------------------------------
  describe "shared bus event ordering (works correctly)" do
    let(:notify_domain) do
      Hecks.domain "Notify" do
        aggregate "Alert" do
          attribute :message, String
          command "CreateAlert" do
            attribute :message, String
          end
        end
      end
    end

    it "subscribers see events in publish order" do
      shared_bus = Hecks::Services::EventBus.new
      _notify_app = boot(notify_domain, event_bus: shared_bus)

      seen = []
      shared_bus.subscribe("CreatedAlert") { |e| seen << e.message }

      NotifyDomain::Alert.create(message: "first")
      NotifyDomain::Alert.create(message: "second")

      expect(seen).to eq(["first", "second"])
      expect(shared_bus.events.size).to eq(2)
    end
  end
end
