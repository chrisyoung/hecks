module BankingDomain
  class Account
    module Subscribers
      class OnDeposited
        EVENT = "Deposited"
        ASYNC = false

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          puts "Deposit receipt for account #{event.account_id}: $#{event.amount}"
        end
      end
    end
  end
end
