module BillingDomain
  class Invoice
    module Events
      class CreatedInvoice
        attr_reader :aggregate_id, :pizza, :quantity, :status, :occurred_at

        def initialize(aggregate_id: nil, pizza: nil, quantity: nil, status: nil)
          @aggregate_id = aggregate_id
          @pizza = pizza
          @quantity = quantity
          @status = status
          @occurred_at = Time.now
          freeze
        end
      end
    end
  end
end
