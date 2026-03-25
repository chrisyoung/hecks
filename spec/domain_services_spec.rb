require "spec_helper"

RSpec.describe "Domain services" do
  let(:domain) do
    Hecks.domain "Banking" do
      aggregate "Account" do
        attribute :balance, Float

        command "Deposit" do
          attribute :account_id, String
          attribute :amount, Float
        end

        command "Withdraw" do
          attribute :account_id, String
          attribute :amount, Float
        end
      end

      service "TransferMoney" do
        attribute :source_id, String
        attribute :target_id, String
        attribute :amount, Float

        call do
          dispatch "Withdraw", account_id: source_id, amount: amount
          dispatch "Deposit",  account_id: target_id, amount: amount
        end
      end
    end
  end

  before { @app = Hecks.load(domain) }

  it "dispatches multiple commands in sequence" do
    source = Account.create(balance: 1000.0)
    target = Account.create(balance: 0.0)

    mod = Object.const_get("BankingDomain")
    events_before = @app.events.size
    mod.transfer_money(source_id: source.id, target_id: target.id, amount: 250.0)

    expect(@app.events.size - events_before).to eq(2) # withdraw + deposit
  end

  it "is available as a method on the domain module" do
    mod = Object.const_get("BankingDomain")
    expect(mod).to respond_to(:transfer_money)
  end

  it "service attributes are accessible in call block" do
    source = Account.create(balance: 500.0)
    target = Account.create(balance: 100.0)

    mod = Object.const_get("BankingDomain")
    results = mod.transfer_money(source_id: source.id, target_id: target.id, amount: 50.0)
    expect(results.size).to eq(2)
  end

  it "stores service definitions on domain IR" do
    expect(domain.services.size).to eq(1)
    expect(domain.services.first.name).to eq("TransferMoney")
    expect(domain.services.first.attributes.map(&:name)).to eq([:source_id, :target_id, :amount])
  end
end
