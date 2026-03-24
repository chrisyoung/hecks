#!/usr/bin/env ruby
#
# Working banking domain with SQLite persistence via Hecks.boot.
#
# Run from the hecks project root:
#   ruby -Ilib examples/banking/sql_app.rb
#
require "hecks"

app = Hecks.boot(__dir__, adapter: :sqlite)

# --- Run the same scenario as app.rb ---

puts "=== Banking Domain (SQLite) ==="

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
Loan.default(loan_id: bad_loan.id, reason: "Missed 3 payments")

# --- Query via the Runtime ---

puts "\n=== Query Results ==="
puts "Customers: #{Customer.count}"
puts "Accounts:  #{Account.count}"
puts "Transfers: #{Transfer.count}"
puts "Loans:     #{Loan.count}"

puts "\nAccount balances:"
Account.all.each do |acct|
  owner = Customer.find(acct.customer_id)
  puts "  #{owner.name} #{acct.account_type}: $#{"%.2f" % acct.balance} (#{acct.status})"
end

puts "\nBob's status: #{Customer.find(bob.id).status}"

puts "\nLoan statuses:"
Loan.all.each do |l|
  owner = Customer.find(l.customer_id)
  puts "  #{owner.name}: $#{"%.2f" % l.principal} at #{l.rate}% — #{l.status} (remaining: $#{"%.2f" % l.remaining_balance})"
end

puts "\nEvent log: #{app.events.size} events"
