module BankingDomain
  class Transfer
    module Events
      class CompletedTransfer
        attr_reader :transfer_id, :occurred_at

        def initialize(transfer_id: nil)
          @transfer_id = transfer_id
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
