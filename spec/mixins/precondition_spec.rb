require "spec_helper"

RSpec.describe "Pre/post conditions on commands" do
  before(:all) do
    @domain = Hecks.domain "ConditionTest" do
      aggregate "Wallet" do
        attribute :owner, String
        attribute :balance, Float

        command "OpenWallet" do
          attribute :owner, String
          attribute :balance, Float
        end

        command "Withdraw" do
          attribute :wallet_id, String
          attribute :amount, Float
          precondition "sufficient funds" do
            existing = repository.find(wallet_id)
            existing.balance >= amount
          end
        end

        command "RejectWithdraw" do
          attribute :wallet_id, String
          attribute :amount, Float
          precondition "always fails" do
            false
          end
        end
      end
    end

    @app = Hecks.load(@domain, force: true)
  end

  it "stores preconditions on the command IR" do
    withdraw = @domain.aggregates.first.commands.find { |c| c.name == "Withdraw" }
    expect(withdraw.preconditions.size).to eq(1)
    expect(withdraw.preconditions.first.message).to eq("sufficient funds")
  end

  it "passes precondition when condition is met" do
    wallet = ConditionTestDomain::Wallet.open(owner: "Alice", balance: 100.0)
    result = ConditionTestDomain::Wallet.withdraw(wallet_id: wallet.id, amount: 50.0)
    expect(result.aggregate).not_to be_nil
  end

  it "raises PreconditionError when condition fails" do
    wallet = ConditionTestDomain::Wallet.open(owner: "Bob", balance: 10.0)
    expect {
      ConditionTestDomain::Wallet.withdraw(wallet_id: wallet.id, amount: 999.0)
    }.to raise_error(Hecks::PreconditionError, /sufficient funds/)
  end

  it "raises PreconditionError for always-false precondition" do
    wallet = ConditionTestDomain::Wallet.open(owner: "Eve", balance: 100.0)
    expect {
      ConditionTestDomain::Wallet.reject_withdraw(wallet_id: wallet.id, amount: 1.0)
    }.to raise_error(Hecks::PreconditionError, /always fails/)
  end

  it "generates precondition comments in command code" do
    withdraw = @domain.aggregates.first.commands.find { |c| c.name == "Withdraw" }
    gen = Hecks::Generators::Domain::CommandGenerator.new(
      withdraw,
      domain_module: "ConditionTestDomain",
      aggregate_name: "Wallet",
      aggregate: @domain.aggregates.first,
      event: @domain.aggregates.first.events[1]
    )
    code = gen.generate
    expect(code).to include("# precondition: sufficient funds")
  end
end
