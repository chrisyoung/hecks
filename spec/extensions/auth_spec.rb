require "spec_helper"
require "hecks/extensions/auth"
require "ostruct"

RSpec.describe "HecksAuth" do
  let(:domain) do
    Hecks.domain "AuthTest" do
      aggregate "Account" do
        attribute :balance, Float

        command "Deposit" do
          actor "AccountHolder"
          attribute :amount, Float
        end

        command "CheckBalance" do
          attribute :account_id, String
        end
      end
    end
  end

  before do
    @app = Hecks.load(domain)
    Hecks.extension_registry[:auth]&.call(
      Object.const_get("AuthTestDomain"), domain, @app
    )
  end

  after { Hecks.actor = nil }

  describe "command with actor" do
    it "raises Unauthenticated when no actor set" do
      expect { Account.deposit(amount: 100.0) }.to raise_error(Hecks::Unauthenticated, /No actor set/)
    end

    it "raises Unauthorized when role doesn't match" do
      Hecks.actor = OpenStruct.new(role: "Guest")
      expect { Account.deposit(amount: 100.0) }.to raise_error(Hecks::Unauthorized, /Guest.*not authorized.*AccountHolder/)
    end

    it "passes when role matches" do
      Hecks.actor = OpenStruct.new(role: "AccountHolder")
      expect { Account.deposit(amount: 100.0) }.not_to raise_error
    end
  end

  describe "command without actor" do
    it "always passes regardless of actor" do
      account = Account.create(balance: 0.0)
      expect { Account.check_balance(account_id: account.id) }.not_to raise_error
    end

    it "passes even with no actor set" do
      Hecks.actor = nil
      account = Account.create(balance: 0.0)
      expect { Account.check_balance(account_id: account.id) }.not_to raise_error
    end
  end

  describe "Hecks.with_actor" do
    it "scopes the actor for the block" do
      Hecks.with_actor(OpenStruct.new(role: "AccountHolder")) do
        expect(Hecks.actor.role).to eq("AccountHolder")
        expect { Account.deposit(amount: 50.0) }.not_to raise_error
      end
      expect(Hecks.actor).to be_nil
    end

    it "restores previous actor after block" do
      outer = OpenStruct.new(role: "Outer")
      Hecks.actor = outer
      Hecks.with_actor(OpenStruct.new(role: "Inner")) do
        expect(Hecks.actor.role).to eq("Inner")
      end
      expect(Hecks.actor.role).to eq("Outer")
    end
  end
end
