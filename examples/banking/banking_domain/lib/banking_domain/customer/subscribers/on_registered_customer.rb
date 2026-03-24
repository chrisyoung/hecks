module BankingDomain
  class Customer
    module Subscribers
      class OnRegisteredCustomer
        EVENT = "RegisteredCustomer"
        ASYNC = false

        def self.event = EVENT
        def self.async = ASYNC

        def call(event)
          puts "Welcome email sent to #{event.email}"
        end
      end
    end
  end
end
