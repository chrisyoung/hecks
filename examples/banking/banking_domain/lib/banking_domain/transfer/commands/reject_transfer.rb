module BankingDomain
  class Transfer
    module Commands
      class RejectTransfer
        emits "RejectedTransfer"

        attr_reader :transfer_id

        def initialize(transfer_id: nil)
          @transfer_id = transfer_id
        end

        def call
          existing = repository.find(transfer_id)
          raise "Transfer not found" unless existing
          Transfer.new(id: existing.id, from_account_id: existing.from_account_id, to_account_id: existing.to_account_id, amount: existing.amount, memo: existing.memo, status: "rejected")
        end
      end
    end
  end
end
