module BankingDomain
  class Customer
    module Commands
      class RegisterCustomer
        emits "RegisteredCustomer"

        attr_reader :name, :email

        def initialize(name: nil, email: nil)
          @name = name
          @email = email
        end

        def call
          Customer.new(name: name, email: email, status: "active")
        end
      end
    end
  end
end
