module BillingDomain
  class Invoice
    module Commands
      class CreateInvoice
        include Hecks::Command
        emits "CreatedInvoice"

        attr_reader :pizza, :quantity

        def initialize(pizza: nil, quantity: nil)
          @pizza = pizza
          @quantity = quantity
        end

        def call
          Invoice.new(pizza: pizza, quantity: quantity)
        end
      end
    end
  end
end
