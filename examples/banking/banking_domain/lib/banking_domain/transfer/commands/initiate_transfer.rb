module BankingDomain
  class Transfer
    module Commands
      class InitiateTransfer
        emits "InitiatedTransfer"

        attr_reader :from_account_id
        attr_reader :to_account_id
        attr_reader :amount
        attr_reader :memo

        def initialize(
          from_account_id: nil,
          to_account_id: nil,
          amount: nil,
          memo: nil
        )
          @from_account_id = from_account_id
          @to_account_id = to_account_id
          @amount = amount
          @memo = memo
        end

        def call
          Transfer.new(from_account_id: from_account_id, to_account_id: to_account_id, amount: amount, memo: memo, status: "pending")
        end
      end
    end
  end
end
