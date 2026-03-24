module BankingDomain
  class Account
    module Commands
      class Withdraw
        emits "Withdrew"

        attr_reader :account_id, :amount

        def initialize(account_id: nil, amount: nil)
          @account_id = account_id
          @amount = amount
        end

        def call
          existing = repository.find(account_id)
          raise "Account not found" unless existing
          new_balance = existing.balance - amount
          raise "Insufficient funds: balance $#{existing.balance}, withdrawal $#{amount}" if new_balance < 0
          raise "Exceeds daily limit of $#{existing.daily_limit}" if amount > existing.daily_limit
          Account.new(id: existing.id, customer_id: existing.customer_id, account_type: existing.account_type, daily_limit: existing.daily_limit, balance: new_balance, status: existing.status)
        end
      end
    end
  end
end
