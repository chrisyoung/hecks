# Domain-Level Policies

Policies that bridge aggregates belong at the domain level, not inside any single aggregate.

## Usage

```ruby
Hecks.domain "Banking" do
  aggregate "Loan" do
    attribute :customer_id, reference_to("Customer")
    attribute :account_id, reference_to("Account")
    attribute :principal, Float

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :account_id, String
      attribute :principal, Float
    end
  end

  aggregate "Account" do
    attribute :balance, Float

    command "Deposit" do
      attribute :account_id, String
      attribute :amount, Float
    end
  end

  # Domain-level: bridges Loan and Account
  policy "DisburseFunds" do
    on "IssuedLoan"
    trigger "Deposit"
    map account_id: :account_id, principal: :amount
  end
end
```

## Output

```
$ ruby -Ilib examples/banking/app.rb

--- Issue loan: $25,000 at 5.25% for 60 months ---
  [event] Deposited $25000.00
  [event] Loan issued: $25000.00 at 5.25%
Alice checking after disbursement: $28000.00
```

The DisburseFunds policy fires when a loan is issued, maps `principal` to `amount`, and triggers a Deposit into the linked account. It lives at the domain level because it coordinates between Loan and Account.

## Conditions work too

```ruby
policy "SuspendOnDefault" do
  on "DefaultedLoan"
  trigger "SuspendCustomer"
  map customer_id: :customer_id
  condition { |event| event.reason != "administrative" }
end
```

## Aggregate-level policies still work

Policies scoped to a single aggregate stay inside the aggregate block. Both levels coexist.
