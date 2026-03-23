require "securerandom"

module BillingDomain
  class ValidationError < StandardError; end
  class InvariantError < StandardError; end

  autoload :Invoice, "billing_domain/invoice/invoice"

  module Ports
    autoload :InvoiceRepository, "billing_domain/ports/invoice_repository"
  end

  module Adapters
    autoload :InvoiceMemoryRepository, "billing_domain/adapters/invoice_memory_repository"
  end
end
