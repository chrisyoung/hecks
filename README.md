# What the Hecks?!

Describe your business in Ruby. Hecks generates the code.

- [The Seam](#the-seam) — the core architecture
- [Quick Start](#quick-start) — zero to running domain
- [The DSL](#the-dsl) — define your business
- [Play Mode](#play-mode) — explore with live objects
- [One-Line SQL](#one-line-sql)
- [Banking Example](#banking-example) — a complete working domain

More: [Specifications](docs/content/specifications.md) · [Policies](docs/usage/policy_conditions.md) · [Domain-Level Policies](docs/usage/domain_level_policies.md) · [Error Messages](docs/usage/error_messages.md) · [Build-Time Checks](#build-time-checks) · [CLI Commands](#cli-commands) · [All Features](FEATURES.md)

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

```
$ hecks new banking
$ cd banking
$ ruby app.rb
```

That's it. One command scaffolds the project. `Hecks.boot(__dir__)` does the rest.

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

```ruby
session = Hecks.session("Demo")
session.aggregate("Cat") do
  attribute :name, String
  command("Adopt") { attribute :name, String }
end

session.play!

whiskers = Cat.adopt(name: "Whiskers")
Cat.adopt(name: "Mittens")

Cat.count              # => 2
Cat.find(whiskers.id)  # => #<Cat name="Whiskers">

whiskers.name = "Sir Whiskers"
whiskers.reset!        # back to "Whiskers"
```

Sketch a domain, play with live objects, persist to memory. Same API as production.

## One-Line SQL

```ruby
app = Hecks.boot(__dir__, adapter: :sqlite)
```

One line. Tables created, adapters wired, data persisted to SQL. Works with SQLite, PostgreSQL, MySQL.

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

Every error includes a fix suggestion. [See examples.](docs/usage/error_messages.md)

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

## License

MIT
