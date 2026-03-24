module BankingDomain
  class Customer
    module Events
      class SuspendedCustomer
        attr_reader :customer_id, :occurred_at

        def initialize(customer_id: nil)
          @customer_id = customer_id
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
