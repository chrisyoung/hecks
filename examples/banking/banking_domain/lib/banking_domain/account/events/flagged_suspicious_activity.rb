module BankingDomain
  class Account
    module Events
      class FlaggedSuspiciousActivity
        attr_reader :account_id, :reason, :occurred_at

        def initialize(account_id: nil, reason: nil)
          @account_id = account_id
          @reason = reason
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
