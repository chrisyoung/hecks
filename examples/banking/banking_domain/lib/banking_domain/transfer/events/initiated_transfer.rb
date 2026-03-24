module BankingDomain
  class Transfer
    module Events
      class InitiatedTransfer
        attr_reader :from_account_id, :to_account_id, :amount, :memo, :occurred_at

        def initialize(from_account_id: nil, to_account_id: nil, amount: nil, memo: nil)
          @from_account_id = from_account_id
          @to_account_id = to_account_id
          @amount = amount
          @memo = memo
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
