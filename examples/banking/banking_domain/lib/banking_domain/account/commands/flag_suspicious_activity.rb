module BankingDomain
  class Account
    module Commands
      class FlagSuspiciousActivity
        emits "FlaggedSuspiciousActivity"

        attr_reader :account_id, :reason

        def initialize(account_id: nil, reason: nil)
          @account_id = account_id
          @reason = reason
        end

        def call
          existing = repository.find(account_id)
          if existing
            Account.new(
              id: existing.id,
              customer_id: existing.customer_id,
              balance: existing.balance,
              account_type: existing.account_type,
              daily_limit: existing.daily_limit,
              status: existing.status
            )
          else
            Account.new()
          end
        end
      end
    end
  end
end
