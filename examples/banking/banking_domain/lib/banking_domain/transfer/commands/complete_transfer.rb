module BankingDomain
  class Transfer
    module Commands
      class CompleteTransfer
        emits "CompletedTransfer"

        attr_reader :transfer_id

        def initialize(transfer_id: nil)
          @transfer_id = transfer_id
        end

        def call
          existing = repository.find(transfer_id)
          raise "Transfer not found" unless existing
          raise "Transfer already #{existing.status}" unless existing.status == "pending"
          Account.withdraw(account_id: existing.from_account_id, amount: existing.amount)
          Account.deposit(account_id: existing.to_account_id, amount: existing.amount)
          Transfer.new(id: existing.id, from_account_id: existing.from_account_id, to_account_id: existing.to_account_id, amount: existing.amount, memo: existing.memo, status: "completed")
        end
      end
    end
  end
end
