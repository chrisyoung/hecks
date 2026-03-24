# Banking Domain Glossary

## Customer

A Customer has a name (String).
A Customer has an email (String).
A Customer has a status (String).
You can register a Customer with name and email. When this happens, a Customer is registered. (command)
You can suspend a Customer with customer id. When this happens, a Customer is suspended. (command)
A Customer must have a name. (validation)
A Customer must have an email. (validation)

## Account

An Account belongs to a Customer.
An Account has a balance (Float).
An Account has an account_type (String).
An Account has a daily_limit (Float).
An Account has a status (String).
You can open an Account with customer id, account type, and daily limit. When this happens, an Account is opened. (command)
You can deposit an Account with account id and amount. When this happens, an Account is deposited. (command)
You can withdraw an Account with account id and amount. When this happens, an Account is withdrew. (command)
You can close an Account with account id. When this happens, an Account is closed. (command)
An Account must have an account_type. (validation)

## Transfer

A Transfer belongs to an Account.
A Transfer belongs to an Account.
A Transfer has an amount (Float).
A Transfer has a status (String).
A Transfer has a memo (String).
You can initiate a Transfer with from account id, to account id, amount, and memo. When this happens, a Transfer is initiated. (command)
You can complete a Transfer with transfer id. When this happens, a Transfer is completed. (command)
You can reject a Transfer with transfer id. When this happens, a Transfer is rejected. (command)
A Transfer must have an amount. (validation)

## Loan

A Loan belongs to a Customer.
A Loan belongs to an Account.
A Loan has a principal (Float).
A Loan has a rate (Float).
A Loan has a term_months (Integer).
A Loan has a remaining_balance (Float).
A Loan has a status (String).
You can issue a Loan with customer id, account id, principal, rate, and term months. When this happens, a Loan is issued. (command)
You can make a Loan with loan id and amount. When this happens, a Payment is made. (command)
You can default a Loan with loan id and customer id. When this happens, a Loan is defaulted. (command)
A Loan must have a principal. (validation)
A Loan must have a rate. (validation)
When a Loan is issued, the system will deposit . (policy)
When a Loan is defaulted, the system will suspend Customer. (policy)

## Relationships

An Account references a Customer.
A Transfer references an Account.
A Transfer references an Account.
A Loan references a Customer.
A Loan references an Account.
