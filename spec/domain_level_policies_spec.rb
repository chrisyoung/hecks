require "spec_helper"

RSpec.describe "Domain-level policies" do
  describe "DSL and IR" do
    it "stores domain-level policies on the Domain" do
      domain = Hecks.domain "T" do
        aggregate "Loan" do
          attribute :amount, Float
          command "IssueLoan" do
            attribute :amount, Float
          end
        end

        aggregate "Account" do
          attribute :balance, Float
          command "Deposit" do
            attribute :amount, Float
          end
        end

        policy "DisburseFunds" do
          on "IssuedLoan"
          trigger "Deposit"
          map amount: :amount
        end
      end

      expect(domain.policies.size).to eq(1)
      pol = domain.policies.first
      expect(pol.name).to eq("DisburseFunds")
      expect(pol.event_name).to eq("IssuedLoan")
      expect(pol.trigger_command).to eq("Deposit")
      expect(pol.attribute_map).to eq({ amount: :amount })
    end

    it "keeps aggregate-level policies separate from domain-level" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
          command "DoB" do
            attribute :n, String
          end
          policy "AggLevel" do
            on "CreatedA"
            trigger "DoB"
          end
        end

        policy "DomainLevel" do
          on "CreatedA"
          trigger "DoB"
        end
      end

      expect(domain.aggregates.first.policies.size).to eq(1)
      expect(domain.aggregates.first.policies.first.name).to eq("AggLevel")
      expect(domain.policies.size).to eq(1)
      expect(domain.policies.first.name).to eq("DomainLevel")
    end

    it "accepts multiple domain-level policies" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
          command "DoB" do
            attribute :n, String
          end
        end

        policy "P1" do
          on "CreatedA"
          trigger "DoB"
        end

        policy "P2" do
          on "CreatedA"
          trigger "DoB"
        end
      end

      expect(domain.policies.size).to eq(2)
      expect(domain.policies.map(&:name)).to eq(["P1", "P2"])
    end

    it "supports conditions on domain-level policies" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :amount, Float
          command "Act" do
            attribute :amount, Float
          end
        end

        policy "ConditionalPolicy" do
          on "Acted"
          trigger "Act"
          condition { |event| event.amount > 100 }
        end
      end

      pol = domain.policies.first
      expect(pol.condition).to be_a(Proc)
    end

    it "defaults to empty policies when none defined" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end
      end

      expect(domain.policies).to eq([])
    end
  end

  describe "runtime" do
    it "subscribes domain-level policies to events" do
      domain = Hecks.domain "CrossAgg" do
        aggregate "Source" do
          attribute :value, Float
          command "Emit" do
            attribute :value, Float
          end
        end

        aggregate "Target" do
          attribute :value, Float
          command "Receive" do
            attribute :value, Float
          end
        end

        policy "Bridge" do
          on "Emitted"
          trigger "Receive"
          map value: :value
        end
      end

      app = Hecks.load(domain, force: true)
      app.run("Emit", value: 42.0)

      event_names = app.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to include("Received")
    end

    it "fires domain-level policies with conditions" do
      domain = Hecks.domain "Conditional" do
        aggregate "Source" do
          attribute :amount, Float
          command "Pay" do
            attribute :amount, Float
          end
        end

        aggregate "Target" do
          attribute :amount, Float
          command "Alert" do
            attribute :amount, Float
          end
        end

        policy "BigPaymentAlert" do
          on "Paid"
          trigger "Alert"
          condition { |event| event.amount > 1000 }
        end
      end

      app = Hecks.load(domain, force: true)

      # Small payment: policy should NOT fire
      app.run("Pay", amount: 100.0)
      event_names = app.events.map { |e| e.class.name.split("::").last }
      expect(event_names).not_to include("Alerted")

      # Big payment: policy should fire
      app.run("Pay", amount: 5000.0)
      event_names = app.events.map { |e| e.class.name.split("::").last }
      expect(event_names).to include("Alerted")
    end

    it "applies attribute mapping on domain-level policies" do
      domain = Hecks.domain "Mapping" do
        aggregate "Loan" do
          attribute :principal, Float
          attribute :account_id, String
          command "IssueLoan" do
            attribute :principal, Float
            attribute :account_id, String
          end
        end

        aggregate "Account" do
          attribute :amount, Float
          attribute :account_id, String
          command "Deposit" do
            attribute :amount, Float
            attribute :account_id, String
          end
        end

        policy "Disburse" do
          on "IssuedLoan"
          trigger "Deposit"
          map principal: :amount, account_id: :account_id
        end
      end

      app = Hecks.load(domain, force: true)
      app.run("IssueLoan", principal: 25000.0, account_id: "acc-1")

      deposit_event = app.events.find { |e| e.class.name.split("::").last == "Deposited" }
      expect(deposit_event).not_to be_nil
      expect(deposit_event.amount).to eq(25000.0)
      expect(deposit_event.account_id).to eq("acc-1")
    end
  end

  describe "serializer" do
    it "serializes domain-level policies" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end

        policy "MyPolicy" do
          on "CreatedA"
          trigger "CreateA"
          map n: :n
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      expect(source).to include('policy "MyPolicy"')
      expect(source).to include('on "CreatedA"')
      expect(source).to include('trigger "CreateA"')
      expect(source).to include("map n: :n")
    end

    it "round-trips domain-level policies through eval" do
      domain = Hecks.domain "RoundTrip" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end

        policy "P1" do
          on "CreatedA"
          trigger "CreateA"
        end
      end

      source = Hecks::DslSerializer.new(domain).serialize
      reloaded = eval(source)

      expect(reloaded.policies.size).to eq(1)
      expect(reloaded.policies.first.name).to eq("P1")
      expect(reloaded.policies.first.event_name).to eq("CreatedA")
      expect(reloaded.policies.first.trigger_command).to eq("CreateA")
    end
  end

  describe "validation" do
    it "warns when domain-level policy event is not in this domain" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end

        policy "External" do
          on "SomeExternalEvent"
          trigger "CreateA"
        end
      end

      rule = Hecks::ValidationRules::Structure::ValidPolicyEvents.new(domain)
      expect(rule.warnings).to include(
        a_string_matching(/Domain policy External listens for SomeExternalEvent/)
      )
    end

    it "does not warn when domain-level policy event exists in domain" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end

        policy "Internal" do
          on "CreatedA"
          trigger "CreateA"
        end
      end

      rule = Hecks::ValidationRules::Structure::ValidPolicyEvents.new(domain)
      expect(rule.warnings).to be_empty
    end

    it "errors when domain-level policy trigger is unknown" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end

        policy "Bad" do
          on "CreatedA"
          trigger "NonexistentCommand"
        end
      end

      rule = Hecks::ValidationRules::Structure::ValidPolicyTriggers.new(domain)
      expect(rule.errors).to include(
        a_string_matching(/Domain policy Bad triggers unknown command: NonexistentCommand/)
      )
    end

    it "accepts domain-level policy with valid trigger" do
      domain = Hecks.domain "T" do
        aggregate "A" do
          attribute :n, String
          command "CreateA" do
            attribute :n, String
          end
        end

        policy "Good" do
          on "CreatedA"
          trigger "CreateA"
        end
      end

      rule = Hecks::ValidationRules::Structure::ValidPolicyTriggers.new(domain)
      expect(rule.errors).to be_empty
    end
  end
end
