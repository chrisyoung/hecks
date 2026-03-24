module BankingDomain
  class Customer
    module Events
      class NotifiedCustomer
        attr_reader :customer_id, :message, :occurred_at

        def initialize(customer_id: nil, message: nil)
          @customer_id = customer_id
          @message = message
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
