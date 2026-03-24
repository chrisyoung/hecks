module BankingDomain
  class Customer
    module Commands
      class SuspendCustomer
        emits "SuspendedCustomer"

        attr_reader :customer_id

        def initialize(customer_id: nil)
          @customer_id = customer_id
        end

        def call
          existing = repository.find(customer_id)
          Customer.new(id: existing.id, name: existing.name, email: existing.email, status: "suspended")
        end
      end
    end
  end
end
