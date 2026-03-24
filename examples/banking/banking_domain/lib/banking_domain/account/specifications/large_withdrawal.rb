module BankingDomain
  class Account
    module Specifications
      class LargeWithdrawal
        def satisfied_by?(withdrawal)
          withdrawal.amount > 10_000
        end
      end
    end
  end
end
