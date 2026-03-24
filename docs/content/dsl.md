```ruby
Hecks.domain "Banking" do
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

    validation :account_type, presence: true

    invariant "balance must not be negative" do
      balance >= 0
    end

    specification "LargeWithdrawal" do |withdrawal|
      withdrawal.amount > 10_000
    end

    query "ByCustomer" do |cid|
      where(customer_id: cid)
    end
  end

  aggregate "Loan" do
    attribute :customer_id, reference_to("Customer")
    attribute :principal, Float
    attribute :rate, Float
    attribute :remaining_balance, Float

    command "IssueLoan" do
      attribute :customer_id, String
      attribute :principal, Float
      attribute :rate, Float
    end

    validation :principal, presence: true

    specification "HighRisk" do |loan|
      loan.principal > 50_000 && loan.rate > 10
    end
  end

  # Domain-level policies — cross-aggregate reactions
  policy "DisburseFunds" do
    on "IssuedLoan"
    trigger "Deposit"
    map account_id: :account_id, principal: :amount
  end
end
```

**Aggregates** are the core business objects -- each gets a unique ID, typed attributes, and commands that describe what you can do with them.

**Value objects** (via `value_object`) are frozen details embedded in an aggregate. **Entities** (via `entity`) are mutable sub-objects with their own identity.

**Commands** become class methods: `Account.open(...)`, `Account.deposit(...)`. Each command auto-generates a domain event (`OpenedAccount`, `Deposited`).

**Validations** are checked at creation time. **Invariants** enforce rules on the aggregate's state.

**Specifications** are reusable predicates -- composable with `and`, `or`, `not`.

**Policies** react to events by triggering other commands. `map` translates event attributes to command attributes. `condition` gates when the policy fires.
