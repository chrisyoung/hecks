require "securerandom"

module BankingDomain
  class ValidationError < StandardError; end
  class InvariantError < StandardError; end

  autoload :Customer, "banking_domain/customer/customer"
  autoload :Account, "banking_domain/account/account"
  autoload :Transfer, "banking_domain/transfer/transfer"
  autoload :Loan, "banking_domain/loan/loan"

  module Ports
    autoload :CustomerRepository, "banking_domain/ports/customer_repository"
    autoload :AccountRepository, "banking_domain/ports/account_repository"
    autoload :TransferRepository, "banking_domain/ports/transfer_repository"
    autoload :LoanRepository, "banking_domain/ports/loan_repository"
  end

  module Adapters
    autoload :CustomerMemoryRepository, "banking_domain/adapters/customer_memory_repository"
    autoload :AccountMemoryRepository, "banking_domain/adapters/account_memory_repository"
    autoload :TransferMemoryRepository, "banking_domain/adapters/transfer_memory_repository"
    autoload :LoanMemoryRepository, "banking_domain/adapters/loan_memory_repository"
  end
end
