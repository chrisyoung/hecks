module BankingDomain
  class Account
    module Commands
      class OpenAccount
        emits "OpenedAccount"

        attr_reader :customer_id
        attr_reader :account_type
        attr_reader :daily_limit

        def initialize(
          customer_id: nil,
          account_type: nil,
          daily_limit: nil
        )
          @customer_id = customer_id
          @account_type = account_type
          @daily_limit = daily_limit
        end

        def call
          Account.new(customer_id: customer_id, account_type: account_type, daily_limit: daily_limit, balance: 0.0, status: "open")
        end
      end
    end
  end
end
