#!/usr/bin/env ruby
#
# Working banking domain — structure in DSL, logic in generated files.
#
# Run from the hecks project root:
#   ruby -Ilib examples/banking/app.rb
#
require "hecks"
require "ostruct"

domain = Hecks.domain "Banking" do
  aggregate "Customer" do
    attribute :name, String
    attribute :email, String
    attribute :status, String, default: "active"

    command "RegisterCustomer" do
      attribute :name, String
      attribute :email, String
    end

    command "SuspendCustomer" do
      attribute :customer_id, String
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
    attribute :ledger, list_of("LedgerEntry")

    entity "LedgerEntry" do
      attribute :amount, Float
      attribute :description, String
      attribute :entry_type, String
      attribute :posted_at, String
    end

    command "OpenAccount" do
      attribute :customer_id, String
      attribute :account_type, String
      attribute :daily_limit, Float
    end

    command "Deposit" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "Withdraw" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "CloseAccount" do
      attribute :account_id, String
    end

    validation :account_type, presence: true

    specification "LargeWithdrawal" do |withdrawal|
      withdrawal.amount > 10_000
    end
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
    end

    command "CompleteTransfer" do
      attribute :transfer_id, String
    end

    command "RejectTransfer" do
      attribute :transfer_id, String
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
    end

    command "MakePayment" do
      attribute :loan_id, String
      attribute :amount, Float
    end

    command "DefaultLoan" do
      attribute :loan_id, String
      attribute :customer_id, String
    end

    validation :principal, presence: true
    validation :rate, presence: true

    specification "HighRisk" do |loan|
      loan.principal > 50_000 && loan.rate > 10
    end

    policy "DisburseFunds" do
      on "IssuedLoan"
      trigger "Deposit"
      map account_id: :account_id, principal: :amount
    end

    policy "SuspendOnDefault" do
      on "DefaultedLoan"
      trigger "SuspendCustomer"
      map customer_id: :customer_id
      condition { |event| event.respond_to?(:customer_id) && event.customer_id }
    end
  end
end

# --- Load and wire ---

puts "=== Banking Domain ==="
valid, errors = Hecks.validate(domain)
puts "Valid: #{valid}"
errors.each { |e| puts "  - #{e}" } unless valid
exit(1) unless valid

# Build regenerates structure but preserves custom call methods
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

puts "\n--- Specifications ---"
high_risk = Loan::Specifications::HighRisk.new
puts "Alice's $25k loan high risk? #{high_risk.satisfied_by?(loan)}"
big_loan = OpenStruct.new(principal: 100_000, rate: 15)
puts "Hypothetical $100k/15% loan high risk? #{high_risk.satisfied_by?(big_loan)}"

large_wd = Account::Specifications::LargeWithdrawal.new
small = OpenStruct.new(amount: 500)
big = OpenStruct.new(amount: 15_000)
puts "Withdrawal $500 large? #{large_wd.satisfied_by?(small)}"
puts "Withdrawal $15k large? #{large_wd.satisfied_by?(big)}"

# Compose specifications
not_high_risk = high_risk.not
puts "Composed not-high-risk for Alice's loan: #{not_high_risk.satisfied_by?(loan)}"

puts "\n--- Ledger entries (sub-entities with identity) ---"
entry1 = BankingDomain::Account::LedgerEntry.new(
  amount: 5000.0, description: "Initial deposit", entry_type: "credit", posted_at: Time.now.to_s
)
entry2 = BankingDomain::Account::LedgerEntry.new(
  amount: 1500.0, description: "ATM withdrawal", entry_type: "debit", posted_at: Time.now.to_s
)
puts "Entry 1 id: #{entry1.id[0..7]}... amount: $#{"%.2f" % entry1.amount} (#{entry1.entry_type})"
puts "Entry 2 id: #{entry2.id[0..7]}... amount: $#{"%.2f" % entry2.amount} (#{entry2.entry_type})"
puts "Entries equal? #{entry1 == entry2}"
puts "Entry mutable? #{!entry1.frozen?}"
entry1.amount = 5500.0
puts "Entry 1 updated amount: $#{"%.2f" % entry1.amount}"

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
