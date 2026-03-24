module BankingDomain
  class Account
    module Events
      class Deposited
        attr_reader :account_id, :amount, :occurred_at

        def initialize(account_id: nil, amount: nil)
          @account_id = account_id
          @amount = amount
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
