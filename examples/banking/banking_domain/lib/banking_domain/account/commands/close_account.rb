module BankingDomain
  class Account
    module Commands
      class CloseAccount
        emits "ClosedAccount"

        attr_reader :account_id

        def initialize(account_id: nil)
          @account_id = account_id
        end

        def call
          existing = repository.find(account_id)
          raise "Account not found" unless existing
          raise "Cannot close account with balance $#{existing.balance}" if existing.balance > 0
          Account.new(id: existing.id, customer_id: existing.customer_id, account_type: existing.account_type, daily_limit: existing.daily_limit, balance: 0.0, status: "closed")
        end
      end
    end
  end
end
