require "spec_helper"

RSpec.describe "DomainDiff behavioral diffs" do
  let(:base_domain) do
    Hecks.domain "Test" do
      aggregate "Account" do
        attribute :name, String
        attribute :balance, Float

        command "CreateAccount" do
          attribute :name, String
        end

        command "Deposit" do
          attribute :amount, Float
        end

        validation :name, presence: true

        invariant("balance must not be negative") { balance.nil? || balance >= 0 }

        query "ByName" do |name|
          where(name: name)
        end

        scope :active, ->(all) { all.select { |a| a.status == "active" } }

        on_event("CreatedAccount") { |e| puts e }

        specification "HighBalance" do |acct|
          acct.balance > 10_000
        end

        policy "NotifyOnCreate" do
          on "CreatedAccount"
          trigger "Deposit"
        end
      end
    end
  end

  describe "commands" do
    it "detects added command" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          command("Withdraw") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_command }
      expect(added.size).to eq(1)
      expect(added.first.details[:name]).to eq("Withdraw")
    end

    it "detects removed command" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_command }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:name]).to eq("Deposit")
    end
  end

  describe "policies" do
    it "detects added policy" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          policy("NotifyOnCreate") { on "CreatedAccount"; trigger "Deposit" }
          policy("FraudAlert") { on "Deposited"; trigger "CreateAccount" }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_policy }
      expect(added.size).to eq(1)
      expect(added.first.details[:name]).to eq("FraudAlert")
    end

    it "detects removed policy" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_policy }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:name]).to eq("NotifyOnCreate")
    end

    it "detects changed policy wiring" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          policy("NotifyOnCreate") { on "Deposited"; trigger "CreateAccount" }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      changed = changes.select { |c| c.kind == :change_policy }
      expect(changed.size).to eq(1)
      expect(changed.first.details[:event]).to eq("Deposited")
    end
  end

  describe "validations" do
    it "detects added validation" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          validation :name, presence: true
          validation :balance, presence: true
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_validation }
      expect(added.size).to eq(1)
      expect(added.first.details[:field]).to eq(:balance)
    end

    it "detects removed validation" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_validation }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:field]).to eq(:name)
    end
  end

  describe "invariants" do
    it "detects added invariant" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          invariant("balance must not be negative") { true }
          invariant("name must not be blank") { true }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_invariant }
      expect(added.size).to eq(1)
      expect(added.first.details[:message]).to eq("name must not be blank")
    end

    it "detects removed invariant" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_invariant }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:message]).to eq("balance must not be negative")
    end
  end

  describe "queries" do
    it "detects added query" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          query("ByName") { |n| where(name: n) }
          query("HighBalance") { where(balance: Hecks::Services::Querying::Operators::Gte.new(10_000)) }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_query }
      expect(added.size).to eq(1)
      expect(added.first.details[:name]).to eq("HighBalance")
    end

    it "detects removed query" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_query }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:name]).to eq("ByName")
    end
  end

  describe "scopes" do
    it "detects added scope" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          scope :active, ->(all) { all }
          scope :closed, ->(all) { all }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_scope }
      expect(added.size).to eq(1)
      expect(added.first.details[:name]).to eq(:closed)
    end

    it "detects removed scope" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_scope }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:name]).to eq(:active)
    end
  end

  describe "subscribers" do
    it "detects added subscriber" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          on_event("CreatedAccount") { |e| puts e }
          on_event("Deposited") { |e| puts e }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_subscriber }
      expect(added.size).to eq(1)
      expect(added.first.details[:event]).to eq("Deposited")
    end

    it "detects removed subscriber" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_subscriber }
      expect(removed.size).to eq(1)
    end
  end

  describe "specifications" do
    it "detects added specification" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
          specification("HighBalance") { |a| a.balance > 10_000 }
          specification("LowBalance") { |a| a.balance < 100 }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      added = changes.select { |c| c.kind == :add_specification }
      expect(added.size).to eq(1)
      expect(added.first.details[:name]).to eq("LowBalance")
    end

    it "detects removed specification" do
      new_domain = Hecks.domain "Test" do
        aggregate "Account" do
          attribute :name, String
          attribute :balance, Float
          command("CreateAccount") { attribute :name, String }
          command("Deposit") { attribute :amount, Float }
        end
      end
      changes = Hecks::Migrations::DomainDiff.call(base_domain, new_domain)
      removed = changes.select { |c| c.kind == :remove_specification }
      expect(removed.size).to eq(1)
      expect(removed.first.details[:name]).to eq("HighBalance")
    end
  end

  describe "no changes in behavior" do
    it "returns no behavioral changes for identical domains" do
      changes = Hecks::Migrations::DomainDiff.call(base_domain, base_domain)
      expect(changes).to be_empty
    end
  end
end
