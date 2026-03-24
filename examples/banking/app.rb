#!/usr/bin/env ruby
#
# Working banking domain — all logic defined through the Hecks DSL.
#
# Run from the hecks project root:
#   ruby -Ilib examples/banking/app.rb
#
require "hecks"

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

    # Deposit principal into linked account when loan is issued
    policy "DisburseFunds" do
      on "IssuedLoan"
      trigger "Deposit"
      map account_id: :account_id, principal: :amount
    end

    # Suspend customer on default
    policy "SuspendOnDefault" do
      on "DefaultedLoan"
      trigger "SuspendCustomer"
      map customer_id: :customer_id
    end
  end
end

# --- Load and wire ---

puts "=== Banking Domain ==="
valid, errors = Hecks.validate(domain)
puts "Valid: #{valid}"
errors.each { |e| puts "  - #{e}" } unless valid
exit(1) unless valid

Hecks.build(domain, version: "1.0.0", output_dir: __dir__)
$LOAD_PATH.unshift(File.join(__dir__, "banking_domain", "lib"))
require "banking_domain"

app = Hecks::Services::Runtime.new(domain)

# --- Event subscriptions ---

app.on("OpenedAccount") { |e| puts "  [event] Opened #{e.account_type} account" }
app.on("Deposited") { |e| puts "  [event] Deposited $#{"%.2f" % e.amount}" }
app.on("Withdrew") { |e| puts "  [event] Withdrew $#{"%.2f" % e.amount}" }
app.on("CompletedTransfer") { |e| puts "  [event] Transfer completed" }
app.on("IssuedLoan") { |e| puts "  [event] Loan issued: $#{"%.2f" % e.principal} at #{e.rate}%" }
app.on("MadePayment") { |e| puts "  [event] Payment: $#{"%.2f" % e.amount}" }
app.on("DefaultedLoan") { |e| puts "  [event] Loan defaulted" }
app.on("SuspendedCustomer") { |e| puts "  [event] Customer suspended" }

# --- Run the scenario ---

puts "\n--- Register customers ---"
alice = Customer.register(name: "Alice Johnson", email: "alice@example.com")
bob = Customer.register(name: "Bob Smith", email: "bob@example.com")
puts "#{alice.name} (#{alice.status})"
puts "#{bob.name} (#{bob.status})"

puts "\n--- Open accounts ---"
checking = Account.open(customer_id: alice.id, account_type: "checking", daily_limit: 5000.0)
savings = Account.open(customer_id: alice.id, account_type: "savings", daily_limit: 10000.0)
bob_acct = Account.open(customer_id: bob.id, account_type: "checking", daily_limit: 3000.0)

puts "\n--- Deposits ---"
checking = Account.deposit(account_id: checking.id, amount: 5000.0)
savings = Account.deposit(account_id: savings.id, amount: 10000.0)
bob_acct = Account.deposit(account_id: bob_acct.id, amount: 2000.0)
puts "Alice checking: $#{"%.2f" % checking.balance}"
puts "Alice savings:  $#{"%.2f" % savings.balance}"
puts "Bob checking:   $#{"%.2f" % bob_acct.balance}"

puts "\n--- Withdraw $1,500 from checking ---"
checking = Account.withdraw(account_id: checking.id, amount: 1500.0)
puts "Alice checking: $#{"%.2f" % checking.balance}"

puts "\n--- Overdraft protection ---"
begin
  Account.withdraw(account_id: checking.id, amount: 99999.0)
rescue => e
  puts "Blocked: #{e.message}"
end

puts "\n--- Daily limit ---"
begin
  Account.withdraw(account_id: checking.id, amount: 4000.0)
rescue => e
  puts "Blocked: #{e.message}"
end

puts "\n--- Transfer $500: Alice -> Bob ---"
xfer = Transfer.initiate(from_account_id: checking.id, to_account_id: bob_acct.id, amount: 500.0, memo: "Dinner last week")
puts "Transfer: $#{"%.2f" % xfer.amount} (#{xfer.status}) — #{xfer.memo}"
xfer = Transfer.complete(transfer_id: xfer.id)
puts "Transfer: #{xfer.status}"
checking = Account.find(checking.id)
bob_acct = Account.find(bob_acct.id)
puts "Alice checking: $#{"%.2f" % checking.balance}"
puts "Bob checking:   $#{"%.2f" % bob_acct.balance}"

puts "\n--- Issue loan: $25,000 at 5.25% for 60 months ---"
loan = Loan.issue(customer_id: alice.id, account_id: checking.id, principal: 25000.0, rate: 5.25, term_months: 60)
puts "Remaining: $#{"%.2f" % loan.remaining_balance}"
checking = Account.find(checking.id)
puts "Alice checking after disbursement: $#{"%.2f" % checking.balance}"

puts "\n--- Make 3 loan payments of $450 ---"
3.times do |i|
  loan = Loan.make_payment(loan_id: loan.id, amount: 450.0)
  puts "Payment #{i + 1}: remaining $#{"%.2f" % loan.remaining_balance}"
end

puts "\n--- Bob defaults on his loan ---"
bad_loan = Loan.issue(customer_id: bob.id, account_id: bob_acct.id, principal: 10000.0, rate: 12.0, term_months: 24)
bad_loan = Loan.default(loan_id: bad_loan.id, customer_id: bob.id)
puts "Loan status: #{bad_loan.status}"
bob = Customer.find(bob.id)
puts "Bob status: #{bob.status}"

puts "\n--- Final state ---"
puts "Customers: #{Customer.count}"
puts "Accounts: #{Account.count}"
puts "Transfers: #{Transfer.count}"
puts "Loans: #{Loan.count}"

puts "\nBalances:"
Account.all.each do |acct|
  owner = Customer.find(acct.customer_id)
  puts "  #{owner.name} #{acct.account_type}: $#{"%.2f" % acct.balance} (#{acct.status})"
end

puts "\nEvent log:"
app.events.each_with_index do |event, i|
  puts "  #{i + 1}. #{event.class.name.split('::').last}"
end
