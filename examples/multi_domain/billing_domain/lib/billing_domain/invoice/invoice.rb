module BillingDomain
  class Invoice

    module Commands
      autoload :CreateInvoice, "billing_domain/invoice/commands/create_invoice"
    end

    module Events
      autoload :CreatedInvoice, "billing_domain/invoice/events/created_invoice"
    end

    module Policies
      autoload :BillOnOrder, "billing_domain/invoice/policies/bill_on_order"
    end

    module Queries
      autoload :Pending, "billing_domain/invoice/queries/pending"
    end

    attr_reader :id, :pizza_id, :quantity, :status, :created_at, :updated_at

    def initialize(pizza_id: nil, quantity: nil, status: nil, id: nil, created_at: nil, updated_at: nil)
      @id = id || generate_id
      @pizza_id = pizza_id
      @quantity = quantity
      @status = status
      @created_at = created_at || Time.now
      @updated_at = updated_at || Time.now
      validate!
      check_invariants!
    end

    def ==(other)
      other.is_a?(self.class) && id == other.id
    end
    alias eql? ==

    def hash
      [self.class, id].hash
    end

    private

    def generate_id
      SecureRandom.uuid
    end

    def validate!; end

    def check_invariants!; end
  end
end
