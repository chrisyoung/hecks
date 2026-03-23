require 'hecks/command'

module BillingDomain
  class Invoice
    module Commands
      class CreateInvoice
        include Hecks::Command
        emits "CreatedInvoice"

        attr_reader :pizza_id, :quantity

        def initialize(pizza_id: nil, quantity: nil)
          @pizza_id = pizza_id
          @quantity = quantity
        end

        def call
          Invoice.new(pizza_id: pizza_id, quantity: quantity)
        end
      end
    end
  end
end
