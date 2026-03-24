module BankingDomain
  class Loan
    module Subscribers
      class OnMadePayment
        EVENT = "MadePayment"
        ASYNC = false

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          puts "Payment of $#{event.amount} received for loan #{event.loan_id}"
        end
      end
    end
  end
end
