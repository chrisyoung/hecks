module BankingDomain
  class Account
    module Commands
      class Deposit
        emits "Deposited"

        attr_reader :account_id, :amount

        def initialize(account_id: nil, amount: nil)
          @account_id = account_id
          @amount = amount
        end

        def call
          existing = repository.find(account_id)
          raise "Account not found" unless existing
          Account.new(id: existing.id, customer_id: existing.customer_id, account_type: existing.account_type, daily_limit: existing.daily_limit, balance: existing.balance + amount, status: existing.status)
        end
      end
    end
  end
end
