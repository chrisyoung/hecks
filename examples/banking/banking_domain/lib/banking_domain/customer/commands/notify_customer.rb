module BankingDomain
  class Customer
    module Commands
      class NotifyCustomer
        emits "NotifiedCustomer"

        attr_reader :customer_id, :message

        def initialize(customer_id: nil, message: nil)
          @customer_id = customer_id
          @message = message
        end

        def call
          existing = repository.find(customer_id)
          if existing
            Customer.new(
              id: existing.id,
              name: existing.name,
              email: existing.email,
              status: existing.status,
              address: existing.address
            )
          else
            Customer.new()
          end
        end
      end
    end
  end
end
