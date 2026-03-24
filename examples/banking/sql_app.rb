#!/usr/bin/env ruby
#
# Working banking domain with SQLite persistence.
#
# Run from the hecks project root:
#   ruby -Ilib examples/banking/sql_app.rb
#
require "hecks"
require "sequel"

domain = Hecks.domain "Banking" do
  aggregate "Customer" do
    attribute :name, String
    attribute :email, String
    attribute :status, String, default: "active"

    command "RegisterCustomer" do
      attribute :name, String
      attribute :email, String
      call do
        Customer.new(name: name, email: email, status: "active")
      end
    end

    command "SuspendCustomer" do
      attribute :customer_id, String
      call do
        existing = repository.find(customer_id)
        Customer.new(id: existing.id, name: existing.name, email: existing.email, status: "suspended")
      end
    end

    validation :name, presence: true
    validation :email, presence: true
  end

  aggregate "Account" do
    attribute :customer_id, reference_to("Customer")
    attribute :balance, Float
    attribute :account_type, String
    attribute :daily_limit, Float
    attribute :status, String, default: "open"

    command "OpenAccount" do
      attribute :customer_id, String
      attribute :account_type, String
      attribute :daily_limit, Float
      call do
        Account.new(customer_id: customer_id, account_type: account_type, daily_limit: daily_limit, balance: 0.0, status: "open")
      end
    end

    command "Deposit" do
      attribute :account_id, String
      attribute :amount, Float
      call do
        existing = repository.find(account_id)
        raise "Account not found" unless existing
        Account.new(id: existing.id, customer_id: existing.customer_id, account_type: existing.account_type, daily_limit: existing.daily_limit, balance: existing.balance + amount, status: existing.status)
      end
    end

    command "Withdraw" do
      attribute :account_id, String
      attribute :amount, Float
      call do
        existing = repository.find(account_id)
        raise "Account not found" unless existing
        new_balance = existing.balance - amount
        raise "Insufficient funds: balance $#{existing.balance}, withdrawal $#{amount}" if new_balance < 0
        raise "Exceeds daily limit of $#{existing.daily_limit}" if amount > existing.daily_limit
        Account.new(id: existing.id, customer_id: existing.customer_id, account_type: existing.account_type, daily_limit: existing.daily_limit, balance: new_balance, status: existing.status)
      end
    end

    command "CloseAccount" do
      attribute :account_id, String
      call do
        existing = repository.find(account_id)
        raise "Account not found" unless existing
        raise "Cannot close account with balance $#{existing.balance}" if existing.balance > 0
        Account.new(id: existing.id, customer_id: existing.customer_id, account_type: existing.account_type, daily_limit: existing.daily_limit, balance: 0.0, status: "closed")
      end
    end

    validation :account_type, presence: true
  end

  aggregate "Transfer" do
    attribute :from_account_id, reference_to("Account")
    attribute :to_account_id, reference_to("Account")
    attribute :amount, Float
    attribute :status, String, default: "pending"
    attribute :memo, String

    command "InitiateTransfer" do
      attribute :from_account_id, String
      attribute :to_account_id, String
      attribute :amount, Float
      attribute :memo, String
      call do
        Transfer.new(from_account_id: from_account_id, to_account_id: to_account_id, amount: amount, memo: memo, status: "pending")
      end
    end

    command "CompleteTransfer" do
      attribute :transfer_id, String
      call do
        existing = repository.find(transfer_id)
        raise "Transfer not found" unless existing
        raise "Transfer already #{existing.status}" unless existing.status == "pending"
        Account.withdraw(account_id: existing.from_account_id, amount: existing.amount)
        Account.deposit(account_id: existing.to_account_id, amount: existing.amount)
        Transfer.new(id: existing.id, from_account_id: existing.from_account_id, to_account_id: existing.to_account_id, amount: existing.amount, memo: existing.memo, status: "completed")
      end
    end

    command "RejectTransfer" do
      attribute :transfer_id, String
      call do
        existing = repository.find(transfer_id)
        raise "Transfer not found" unless existing
        Transfer.new(id: existing.id, from_account_id: existing.from_account_id, to_account_id: existing.to_account_id, amount: existing.amount, memo: existing.memo, status: "rejected")
      end
    end

    validation :amount, presence: true
  end

  aggregate "Loan" do
    attribute :customer_id, reference_to("Customer")
    attribute :account_id, reference_to("Account")
    attribute :principal, Float
    attribute :rate, Float
    attribute :term_months, Integer
    attribute :remaining_balance, Float
    attribute :status, String, default: "active"

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :account_id, String
      attribute :principal, Float
      attribute :rate, Float
      attribute :term_months, Integer
      call do
        Loan.new(customer_id: customer_id, account_id: account_id, principal: principal, rate: rate, term_months: term_months, remaining_balance: principal, status: "active")
      end
    end

    command "MakePayment" do
      attribute :loan_id, String
      attribute :amount, Float
      call do
        existing = repository.find(loan_id)
        raise "Loan not found" unless existing
        raise "Loan is #{existing.status}" unless existing.status == "active"
        new_balance = existing.remaining_balance - amount
        new_status = new_balance <= 0 ? "paid_off" : "active"
        Loan.new(id: existing.id, customer_id: existing.customer_id, account_id: existing.account_id, principal: existing.principal, rate: existing.rate, term_months: existing.term_months, remaining_balance: [new_balance, 0.0].max, status: new_status)
      end
    end

    command "DefaultLoan" do
      attribute :loan_id, String
      attribute :customer_id, String
      call do
        existing = repository.find(loan_id)
        raise "Loan not found" unless existing
        Loan.new(id: existing.id, customer_id: existing.customer_id, account_id: existing.account_id, principal: existing.principal, rate: existing.rate, term_months: existing.term_months, remaining_balance: existing.remaining_balance, status: "defaulted")
      end
    end

    validation :principal, presence: true
    validation :rate, presence: true

    policy "DisburseFunds" do
      on "IssuedLoan"
      trigger "Deposit"
      map account_id: :account_id, principal: :amount
    end

    policy "SuspendOnDefault" do
      on "DefaultedLoan"
      trigger "SuspendCustomer"
      map customer_id: :customer_id
    end
  end
end

# --- Build and load ---

puts "=== Banking Domain (SQLite) ==="
output = Hecks.build(domain, version: "1.0.0", output_dir: __dir__)
$LOAD_PATH.unshift(File.join(output, "lib"))
require "banking_domain"
Dir[File.join(output, "lib/**/*.rb")].sort.each do |f|
  next if f.include?("/commands/") || f.include?("/queries/")
  load f
end

# --- Generate SQL adapters ---

mod = "BankingDomain"
domain.aggregates.each do |agg|
  gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: mod)
  eval(gen.generate, TOPLEVEL_BINDING)
end

# --- Create SQLite schema ---

db = Sequel.sqlite

db.create_table(:customers) do
  String :id, primary_key: true, size: 36
  String :name, null: false
  String :email, null: false
  String :status
  String :created_at
  String :updated_at
end

db.create_table(:accounts) do
  String :id, primary_key: true, size: 36
  String :customer_id, null: false
  Float :balance
  String :account_type, null: false
  Float :daily_limit
  String :status
  String :created_at
  String :updated_at
end

db.create_table(:transfers) do
  String :id, primary_key: true, size: 36
  String :from_account_id, null: false
  String :to_account_id, null: false
  Float :amount, null: false
  String :status
  String :memo
  String :created_at
  String :updated_at
end

db.create_table(:loans) do
  String :id, primary_key: true, size: 36
  String :customer_id, null: false
  String :account_id, null: false
  Float :principal, null: false
  Float :rate, null: false
  Integer :term_months
  Float :remaining_balance
  String :status
  String :created_at
  String :updated_at
end

# --- Wire with SQL adapters ---

app = Hecks::Services::Runtime.new(domain) do
  adapter "Customer", BankingDomain::Adapters::CustomerSqlRepository.new(db)
  adapter "Account", BankingDomain::Adapters::AccountSqlRepository.new(db)
  adapter "Transfer", BankingDomain::Adapters::TransferSqlRepository.new(db)
  adapter "Loan", BankingDomain::Adapters::LoanSqlRepository.new(db)
end

# --- Run the same scenario ---

puts "\n--- Register customers ---"
alice = Customer.register(name: "Alice Johnson", email: "alice@example.com")
bob = Customer.register(name: "Bob Smith", email: "bob@example.com")
puts "#{alice.name}, #{bob.name}"

puts "\n--- Open accounts ---"
checking = Account.open(customer_id: alice.id, account_type: "checking", daily_limit: 5000.0)
savings = Account.open(customer_id: alice.id, account_type: "savings", daily_limit: 10000.0)
bob_acct = Account.open(customer_id: bob.id, account_type: "checking", daily_limit: 3000.0)

puts "\n--- Deposits ---"
Account.deposit(account_id: checking.id, amount: 5000.0)
Account.deposit(account_id: savings.id, amount: 10000.0)
Account.deposit(account_id: bob_acct.id, amount: 2000.0)

puts "\n--- Withdraw & transfer ---"
Account.withdraw(account_id: checking.id, amount: 1500.0)
xfer = Transfer.initiate(from_account_id: checking.id, to_account_id: bob_acct.id, amount: 500.0, memo: "Dinner")
Transfer.complete(transfer_id: xfer.id)

puts "\n--- Issue loan with auto-disbursement ---"
loan = Loan.issue(customer_id: alice.id, account_id: checking.id, principal: 25000.0, rate: 5.25, term_months: 60)
3.times { loan = Loan.make_payment(loan_id: loan.id, amount: 450.0) }

puts "\n--- Default Bob's loan ---"
bad_loan = Loan.issue(customer_id: bob.id, account_id: bob_acct.id, principal: 10000.0, rate: 12.0, term_months: 24)
Loan.default(loan_id: bad_loan.id, customer_id: bob.id)

# --- Query SQLite ---

puts "\n=== SQLite Queries ==="
puts "Customers: #{db[:customers].count}"
puts "Accounts:  #{db[:accounts].count}"
puts "Transfers: #{db[:transfers].count}"
puts "Loans:     #{db[:loans].count}"

puts "\nAccount balances (from SQLite):"
db[:accounts].each do |row|
  owner = db[:customers].where(id: row[:customer_id]).first
  puts "  #{owner[:name]} #{row[:account_type]}: $#{"%.2f" % row[:balance]} (#{row[:status]})"
end

puts "\nBob's status: #{db[:customers].where(id: bob.id).first[:status]}"

puts "\nLoan statuses:"
db[:loans].each do |row|
  owner = db[:customers].where(id: row[:customer_id]).first
  puts "  #{owner[:name]}: $#{"%.2f" % row[:principal]} at #{row[:rate]}% — #{row[:status]} (remaining: $#{"%.2f" % row[:remaining_balance]})"
end

puts "\nEvent log: #{app.events.size} events"
