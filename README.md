# What the Hecks?!

Describe your business in Ruby. Hecks generates the code.

## The Seam

A domain has a boundary. **Ports are the only way through it.**

```ruby
# The domain — pure structure and intent
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end

# Ports — how the domain connects to everything else
PizzasDomain.persist_to(:sql)
PizzasDomain.port(DeliveryDomain)
PizzasDomain.port(:notifications, SendgridAdapter.new)
PizzasDomain.port(:tenant, ColumnTenant.new)
```

Three interfaces, one concept:

- **Class methods** — outside world commands the domain: `Pizza.create(name: "Margherita")`
- **Instance methods** — domain objects talk to each other: `pizza.deliver`
- **Ports** — domain reaches the outside world: events, persistence, other domains

Domains don't call each other's commands. They subscribe to each other's events through ports:

```ruby
PizzasDomain.port(DeliveryDomain)   # Pizza events visible to Delivery
DeliveryDomain.port(PizzasDomain)   # Delivery events visible to Pizza
```

Pizza emits `PizzaReady`. Delivery reacts with `ScheduleDelivery`. Delivery emits `DeliveryCompleted`. Pizza reacts with `MarkDelivered`. Two domains, zero coupling.

A port is just a block of code plugged into a named slot:

```ruby
PizzasDomain.port(:notifications) do |event|
  Sendgrid.send(to: event.email, body: "Your pizza is ready")
end
```

No adapter class needed unless you want one. Persistence is a port. Notifications is a port. Another domain is a port. Tenancy is a port. Everything outside the boundary is a port.

*Know DDD? See [how Hecks maps to DDD patterns](docs/ddd.md).*

*Love hexagonal architecture? See [how Hecks implements ports and adapters](docs/hexagonal.md).*

*Using Rails? See [how ActiveHecks bridges domain objects and Rails](docs/active_hecks.md).*

## Quick Start

Create a complete Hecks project in one command.


```
$ hecks new banking

Created banking/
  hecks_domain.rb
  app.rb
  Gemfile
  spec/spec_helper.rb
  .gitignore
  .rspec

Get started:
  cd banking
  bundle install
  ruby app.rb
```


**hecks_domain.rb** — starter domain definition:
```ruby
Hecks.domain "Banking" do
  aggregate "Example" do
    attribute :name, String

    command "CreateExample" do
      attribute :name, String
    end
  end
end
```

**app.rb** — one-line boot:
```ruby
require "hecks"

app = Hecks.boot(__dir__)

# Start building:
#   Example.create(name: "Hello")
#   Example.all
```


`Hecks.boot(__dir__)` replaces the manual load/validate/build/require/wire dance:

```ruby
# Before (10 lines):
domain_file = File.join(__dir__, "hecks_domain.rb")
domain = eval(File.read(domain_file), nil, domain_file, 1)
Hecks.validate(domain)
output = Hecks.build(domain, output_dir: __dir__)
$LOAD_PATH.unshift(File.join(output, "lib"))
require "banking_domain"
app = Hecks::Services::Runtime.new(domain)

# After (1 line):
app = Hecks.boot(__dir__)
```

It finds `hecks_domain.rb`, validates, builds the gem, loads it, and returns a Runtime.


```ruby
require "hecks"
app = Hecks.boot(__dir__)

Example.create(name: "Widget")
Example.create(name: "Gadget")
Example.count  # => 2
Example.all.each { |e| puts e.name }
```

```
Widget
Gadget
```

## The DSL

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

## Play Mode

Play mode now uses a full Runtime with memory adapters. Aggregates are persisted, queryable, and countable after executing commands.


```ruby
session = Hecks.session("Demo")
session.aggregate("Cat") do
  attribute :name, String
  command("Adopt") { attribute :name, String }
end

session.play!

# Execute commands — aggregates are persisted
whiskers = session.execute("Adopt", name: "Whiskers")
session.execute("Adopt", name: "Mittens")

# Find, all, count — they work
Cat.find(whiskers.id)   # => #<Cat name="Whiskers">
Cat.all.map(&:name)     # => ["Whiskers", "Mittens"]
Cat.count               # => 2

# Class method shortcuts also persist
Cat.adopt(name: "Shadow")
Cat.count               # => 3

# Reset clears events AND repository data
session.reset!
Cat.count               # => 0
```


```
Command: Adopt
  Event: Adopted
    name: "Whiskers"

Cat.count: 2
Cat.all: ["Whiskers", "Mittens"]
Cat.find(d67296b0...): Whiskers

Cat.adopt(name: "Shadow"): Shadow
Cat.count: 3

Cleared all events and data
Cat.count: 0
```


Play mode previously recorded events but didn't persist aggregates. Now it boots a real `Services::Runtime` with memory adapters, giving you the full command lifecycle: guard, handler, call, persist, emit, record. Same API as production, just in-memory.

## Specifications

Specifications are reusable business predicates defined in the DSL. Each becomes a class with a `satisfied_by?` method.

```ruby
aggregate "Loan" do
  specification "HighRisk" do |loan|
    loan.principal > 50_000 && loan.rate > 10
  end
end

aggregate "Account" do
  specification "LargeWithdrawal" do |withdrawal|
    withdrawal.amount > 10_000
  end
end
```

Use them at runtime:

```ruby
high_risk = Loan::Specifications::HighRisk.new
high_risk.satisfied_by?(loan)  # => true or false
```

Compose specifications with `and`, `or`, and `not`:

```ruby
high_risk = Loan::Specifications::HighRisk.new
large     = Account::Specifications::LargeWithdrawal.new

# Combine with logical operators
risky_and_large = high_risk.and(large)
risky_or_large  = high_risk.or(large)
not_risky       = high_risk.not
```

## Policies

Reactive policies can have a `condition` block that gates when they fire. The block receives the event and must return true for the policy to trigger.


```ruby
Hecks.domain "Banking" do
  aggregate "Account" do
    attribute :balance, Float

    command "Withdraw" do
      attribute :account_id, String
      attribute :amount, Float
    end

    command "FlagSuspicious" do
      attribute :account_id, String
    end

    # Only flag withdrawals over $10,000
    policy "FraudAlert" do
      on "Withdrew"
      trigger "FlagSuspicious"
      map account_id: :account_id
      condition { |event| event.amount > 10_000 }
    end
  end
end
```


```ruby
# Small withdrawal — policy does NOT fire
Account.withdraw(account_id: acct.id, amount: 500.0)
# => Withdrew event, no FraudAlert

# Large withdrawal — policy fires
Account.withdraw(account_id: acct.id, amount: 25_000.0)
# => Withdrew event
# => Policy: FraudAlert -> FlagSuspicious
```


Policies without a `condition` block fire on every matching event (backward compatible):

```ruby
policy "NotifyOnDeposit" do
  on "Deposited"
  trigger "SendReceipt"
end
# Fires on every Deposited event
```

## Domain-Level Policies

Policies that bridge aggregates belong at the domain level, not inside any single aggregate.


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


```
$ ruby -Ilib examples/banking/app.rb

--- Issue loan: $25,000 at 5.25% for 60 months ---
  [event] Deposited $25000.00
  [event] Loan issued: $25000.00 at 5.25%
Alice checking after disbursement: $28000.00
```

The DisburseFunds policy fires when a loan is issued, maps `principal` to `amount`, and triggers a Deposit into the linked account. It lives at the domain level because it coordinates between Loan and Account.


```ruby
policy "SuspendOnDefault" do
  on "DefaultedLoan"
  trigger "SuspendCustomer"
  map customer_id: :customer_id
  condition { |event| event.reason != "administrative" }
end
```


Policies scoped to a single aggregate stay inside the aggregate block. Both levels coexist.

## SQL Persistence

One line to go from domain definition to SQL-backed persistence.


```ruby
require "hecks"

# In-memory SQLite (great for development)
app = Hecks.boot(__dir__, adapter: :sqlite)

# File-based SQLite
app = Hecks.boot(__dir__, adapter: { type: :sqlite, database: "banking.db" })

# PostgreSQL (future)
app = Hecks.boot(__dir__, adapter: { type: :postgres, host: "localhost", database: "banking" })
```


`Hecks.boot` with an adapter option automatically:
1. Requires Sequel
2. Creates the database connection
3. Generates SQL repository classes for each aggregate
4. Creates tables from the domain IR (columns, types, join tables)
5. Wires everything into a Runtime


```ruby
# Before (30+ lines):
require "sequel"
db = Sequel.sqlite
db.create_table(:accounts) { String :id, primary_key: true; Float :balance; ... }
# ... repeat for every aggregate ...
gen = Hecks::Generators::SQL::SqlAdapterGenerator.new(agg, domain_module: mod)
eval(gen.generate, TOPLEVEL_BINDING)
# ... repeat for every aggregate ...
app = Hecks::Services::Runtime.new(domain) do
  adapter "Account", AccountSqlRepository.new(db)
  # ... repeat ...
end

# After (1 line):
app = Hecks.boot(__dir__, adapter: :sqlite)
```


```ruby
require "hecks"
app = Hecks.boot(__dir__, adapter: :sqlite)

Customer.register(name: "Alice", email: "alice@example.com")
Account.open(customer_id: alice.id, account_type: "checking", daily_limit: 5000.0)
Account.deposit(account_id: acct.id, amount: 1000.0)

# Data persists in SQL
Account.count  # => 1
Account.find(acct.id).balance  # => 1000.0
```

## Error Messages

Every validation error includes a suggestion for how to fix it.


```ruby
domain = Hecks.domain "Test" do
  aggregate "Pizza" do
    attribute :name, String
    # no commands — will fail validation
  end
end

valid, errors = Hecks.validate(domain)
errors.each { |e| puts e }
```

```
Pizza has no commands. Add a command: command "CreatePizza" do attribute :name, String end
```


**Bad command name:**
```
Command Data in Pizza doesn't start with a verb. Try 'CreateData' or register
a custom verb with add_verb('Data') or verbs.txt.
```

**Unknown reference:**
```
Reference 'Order' in Pizza.order_id not found. Available aggregates: Customer, Account.
```

**Missing policy event:**
```
Policy NotifyKitchen in Pizza references unknown event: Cooked.
Known events: CreatedPizza, UpdatedPizza.
```

**Missing policy trigger:**
```
Policy NotifyKitchen in Pizza triggers unknown command: Cook.
Available commands: CreatePizza, UpdatePizza.
```

**Bidirectional reference:**
```
Bidirectional reference between Pizza and Order. Remove the reference from
one side — in DDD, only one aggregate should hold the reference. Use a
domain-level policy to coordinate.
```

## Build-Time Checks

| Rule | Description |
|---|---|
| CommandNaming | Rejects command names that do not start with a verb |
| NameCollisions | Rejects aggregate root names that collide with their own value object |
| ReservedNames | Rejects attribute names that are Ruby keywords, and aggregate names |
| UniqueAggregateNames | Rejects duplicate aggregate names within a domain |
| NoBidirectionalReferences | Rejects bidirectional references between aggregates (A->B and B->A) |
| NoSelfReferences | Rejects aggregates that reference themselves |
| NoValueObjectReferences | Rejects reference attributes on value objects |
| ValidReferences | Rejects references to non-existent aggregates and references that |
| AggregatesHaveCommands | Rejects aggregates that have no commands -- an aggregate without |
| CommandsHaveAttributes | Rejects commands that have no attributes |
| ValidPolicyEvents | Produces warnings (not errors) when policies listen for events not defined |
| ValidPolicyTriggers | Rejects policies whose trigger_command does not match any command |

## CLI Commands

| Command | Description |
|---|---|
| `hecks build` | Validates the domain, assigns a CalVer version, and generates the domain gem |
| `hecks console` | Launches an interactive REPL session via Session::ConsoleRunner |
| `hecks docs` | Starts a WEBrick server hosting Swagger UI for a domain's API |
| `hecks dump` | Extracts domain artifacts to the filesystem |
| `hecks gem` | Gem packaging commands — build and install the hecks gem from its gemspec |
| `hecks generate sinatra` | Scaffolds a Sinatra web app from a domain definition |
| `hecks init` | Scaffolds a new Hecks domain in the current directory |
| `hecks list` | Lists all installed Hecks domain gems found via RubyGems, showing |
| `hecks mcp` | Starts an MCP (Model Context Protocol) server |
| `hecks migrations` | Three migration-related subcommands: |
| `hecks new project` | Scaffolds a new Hecks project directory with a domain definition, app.rb, |
| `hecks serve` | Serves a domain over HTTP |
| `hecks validate` | Validates the domain definition and prints a summary of all aggregates, |
| `hecks version` | Shows the Hecks framework version, or the version of a specific domain gem |

## All Features

See [FEATURES.md](FEATURES.md) for the complete feature list.

## Banking Example

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

## License

MIT
