module BillingDomain
  module Ports
    module InvoiceRepository
      def find(id)
        raise NotImplementedError, "#{self.class}#find not implemented"
      end

      def save(invoice)
        raise NotImplementedError, "#{self.class}#save not implemented"
      end

      def delete(id)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
    end
  end
end
