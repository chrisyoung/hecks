module BankingDomain
  class Customer
    module Events
      class RegisteredCustomer
        attr_reader :name, :email, :occurred_at

        def initialize(name: nil, email: nil)
          @name = name
          @email = email
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
