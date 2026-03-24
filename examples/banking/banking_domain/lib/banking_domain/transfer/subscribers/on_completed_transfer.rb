module BankingDomain
  class Transfer
    module Subscribers
      class OnCompletedTransfer
        EVENT = "CompletedTransfer"
        ASYNC = false

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          puts "Transfer #{event.transfer_id} completed — notify both parties"
        end
      end
    end
  end
end
