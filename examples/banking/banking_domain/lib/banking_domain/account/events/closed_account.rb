module BankingDomain
  class Account
    module Events
      class ClosedAccount
        attr_reader :account_id, :occurred_at

        def initialize(account_id: nil)
          @account_id = account_id
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
