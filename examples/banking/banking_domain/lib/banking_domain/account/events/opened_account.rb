module BankingDomain
  class Account
    module Events
      class OpenedAccount
        attr_reader :customer_id, :account_type, :daily_limit, :occurred_at

        def initialize(customer_id: nil, account_type: nil, daily_limit: nil)
          @customer_id = customer_id
          @account_type = account_type
          @daily_limit = daily_limit
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
