The `examples/banking/` directory contains a complete domain with four aggregates: Customer, Account, Transfer, and Loan. It demonstrates cross-aggregate policies, specifications, entities, and business logic in generated command files.

Run it:

```bash
ruby -Ilib examples/banking/app.rb
```

The scenario:

1. **Register** two customers (Alice and Bob)
2. **Open accounts** -- checking and savings for Alice, checking for Bob
3. **Deposit** funds into each account
4. **Withdraw** from checking -- succeeds for $1,500, blocked for overdraft and daily limit
5. **Transfer** $500 from Alice to Bob -- initiates, then completes
6. **Issue a loan** -- $25,000 at 5.25% for 60 months, auto-disburses to Alice's checking via the `DisburseFunds` policy
7. **Make loan payments** -- three payments of $450 reduce the remaining balance
8. **Default a loan** -- Bob's loan defaults, triggering `SuspendOnDefault` policy which suspends Bob's customer record
9. **Specifications** -- `HighRisk` checks whether a loan exceeds $50k principal and 10% rate

Key output:

```
Alice checking: $5000.00
Blocked: Insufficient funds: balance $3500.0, withdrawal $99999.0
Transfer: completed
Alice checking after disbursement: $28000.00
Loan status: defaulted
Bob status: suspended
Alice's $25k loan high risk? false
Hypothetical $100k/15% loan high risk? true
```

The domain-level policies (`DisburseFunds` and `SuspendOnDefault`) show cross-aggregate event-driven reactions with attribute mapping and conditions.
