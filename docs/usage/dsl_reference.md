# Hecks DSL Reference

> Generated from Hecks v2026.03.31.13

Complete reference for the Bluebook domain definition language.

## Domain

Entry point for defining a domain. Everything lives inside a `Hecks.domain` block.

```ruby
Hecks.domain "Pizzas" do
  aggregate "Pizza" do
    # ...
  end
end
```

### Domain-level methods

```ruby
Hecks.domain "Banking" do
  # Aggregates
  aggregate "Account" do ... end

  # Cross-aggregate reactive policies
  policy "DisburseFunds" do
    on "IssuedLoan"
    trigger "Deposit"
    map principal: :amount
  end

  # Domain services (coordinate multiple aggregates)
  service "TransferMoney" do
    attribute :source_id, String
    attribute :dest_id, String
    attribute :amount, Float
    coordinates "Account", "Ledger"
    call do
      dispatch("Withdraw", account_id: source_id, amount: amount)
      dispatch("Deposit", account_id: dest_id, amount: amount)
    end
  end

  # Read model projections
  view "OrderSummary" do
    project("PlacedOrder") { |event, state| state.merge(total: event.quantity) }
  end

  # Workflows with branching
  workflow "LoanApproval" do
    step "ScoreLoan", score: :principal
    branch do
      when_spec("HighRisk") { step "ReviewLoan" }
      otherwise { step "ApproveLoan" }
    end
  end

  # Scheduled workflows
  workflow "OverdueCheck" do
    schedule "daily"
    step "ProcessOverdue" do
      find "Loan", spec: :overdue
      trigger "MarkDelinquent"
    end
  end

  # Actors
  actor "Customer"
  actor "Admin", description: "System administrator"

  # Multi-tenancy
  tenancy :row

  # Ubiquitous language enforcement
  glossary do
    prefer "stakeholder", not: ["user", "person"]
  end

  # Logical grouping
  domain_module "PolicyManagement" do
    aggregate "GovernancePolicy" do ... end
  end

  # Domain-level event subscriber
  on_event "CreatedPizza" do |event|
    puts event.name
  end
end
```

### Implicit syntax

PascalCase names with blocks become aggregates:

```ruby
Hecks.domain "Pizzas" do
  Pizza do
    attribute :name, String
    command "CreatePizza" do
      attribute :name, String
    end
  end
end
```

---

## Aggregate

The core building block. Groups attributes, references, commands, value objects,
entities, queries, policies, and lifecycle.

```ruby
aggregate "Pizza" do
  # Attributes
  attribute :name, String
  attribute :description, String
  attribute :price, Float
  attribute :active, :boolean
  attribute :metadata, Hash
  attribute :toppings, list_of("Topping")
  attribute :status, String, default: "draft"
  attribute :category, String, enum: ["classic", "specialty", "seasonal"]
  attribute :email, String, pii: true

  # References (relationships to other aggregates)
  reference_to "Restaurant"
  reference_to "Team", role: "home_team"      # explicit role
  reference_to "Billing::Invoice"             # cross-domain

  # Value objects (immutable, no identity)
  value_object "Topping" do
    attribute :name, String
    attribute :amount, Integer
    invariant "amount must be positive" do
      amount > 0
    end
  end

  # Entities (mutable, with identity)
  entity "LedgerEntry" do
    attribute :amount, Float
    attribute :description, String
  end

  # Commands
  command "CreatePizza" do
    attribute :name, String
    attribute :description, String
  end

  # Validations
  validation :name, presence: true
  validation :email, presence: true, type: String, uniqueness: true

  # Invariants
  invariant "price must be positive" do
    price > 0
  end

  # Lifecycle (state machine)
  lifecycle :status, default: "draft" do
    transition "PublishPizza" => "published", from: "draft"
    transition "ArchivePizza" => "archived", from: ["draft", "published"]
  end

  # Queries
  query "ByDescription" do |desc|
    where(description: desc)
  end

  # Scopes
  scope :active, status: "active"
  scope :by_style, ->(style) { { style: style } }

  # Indexes
  index :email, unique: true
  index :name, :status

  # Specifications (reusable predicates)
  specification "HighValue" do |pizza|
    pizza.price > 20
  end

  # Policies (reactive: event -> trigger)
  policy "NotifyKitchen" do
    on "CreatedPizza"
    trigger "PrepareIngredients"
    async true
    condition { |event| event.name != "Test" }
  end

  # Ports (access control per role)
  port :admin do
    allow :find, :all, :create_pizza, :archive_pizza
  end
  port :guest, [:find, :all]

  # Event subscribers
  on_event "CreatedPizza", async: true do |event|
    puts "Pizza created: #{event.name}"
  end

  # Repository interface
  repository :find, :all, :save, :delete

  # Factories
  factory "BuildFromCart" do
    attribute :cart_id, String
  end

  # Explicit events (not inferred from commands)
  event "PizzaExpired" do
    attribute :reason, String
  end

  # Versioning and attachments
  versioned
  attachable
end
```

### Implicit syntax

Inside an aggregate block:

```ruby
aggregate "Pizza" do
  name String                    # attribute :name, String
  price Float                    # attribute :price, Float

  Topping do                     # value_object "Topping" do
    name String
    amount Integer
  end

  create do                      # command "CreatePizza" do
    name String
    price Float
  end
end
```

---

## Command

Declares an intent to change aggregate state. Each command automatically
infers a corresponding domain event (CreatePizza -> CreatedPizza).

```ruby
command "PlaceOrder" do
  # Input attributes
  attribute :customer_name, String
  attribute :quantity, Integer

  # References to other aggregates
  reference_to "Pizza"
  reference_to "Restaurant", role: "pickup_location"

  # Guard policy (must pass before execution)
  guarded_by "MustBeAuthenticated"

  # Static field assignments
  sets status: "pending", ordered_at: :now

  # Actors who can issue this command
  actor "Customer"
  actor "Admin"

  # Documentation: what data this command needs
  read_model "Menu & Availability"

  # External system dependencies
  external "PaymentGateway"

  # Pre/postconditions
  precondition "quantity must be positive" do |agg|
    quantity > 0
  end

  postcondition "order count increased" do |before, after|
    after.count > before.count
  end

  # Custom handler (overrides default create/update)
  handler do |cmd, agg|
    # complex domain logic
  end

  # Or inline call body
  call do
    # lightweight logic
  end
end
```

### Event inference

The command verb is automatically converted to past tense:

| Command | Inferred Event |
|---------|---------------|
| CreatePizza | CreatedPizza |
| PlaceOrder | PlacedOrder |
| SubmitApplication | SubmittedApplication |
| SendInvoice | SentInvoice |
| DenyRequest | DeniedRequest |

### Implicit syntax

Inside a command block:

```ruby
command "CreatePizza" do
  name String        # attribute :name, String
  price Float        # attribute :price, Float
end
```

---

## Reference

Declares a relationship to another aggregate. The domain layer holds
live object references -- IDs are purely a persistence concern.

```ruby
aggregate "Order" do
  # Role defaults to downcased type name (:pizza)
  reference_to "Pizza"

  # Explicit role (required when multiple refs to same type)
  reference_to "Team", role: "home_team"
  reference_to "Team", role: "away_team"

  # Cross-domain reference
  reference_to "Billing::Invoice"

  # References in commands
  command "PlaceOrder" do
    reference_to "Pizza"
    attribute :quantity, Integer
  end
end
```

Reference kinds (inferred automatically after build):

| Kind | When |
|------|------|
| `:composition` | Target is a value object or entity within the same aggregate |
| `:aggregation` | Target is another aggregate root |
| `:cross_context` | Target is in a different bounded context (qualified with `::`) |

---

## Types

### Built-in types

| Type | Aliases |
|------|---------|
| `String` | `:string`, `:str` |
| `Integer` | `:integer`, `:int` |
| `Float` | `:float` |
| `TrueClass` (Boolean) | `:boolean`, `:bool` |
| `Symbol` | `:symbol`, `:sym` |
| `Array` | `:array` |
| `Hash` | `:hash` |
| `Date` | `:date` |
| `DateTime` | `:datetime` |
| `JSON` | (use directly) |

### Collection types

```ruby
attribute :toppings, list_of("Topping")
attribute :tags, list_of(String)
```

### Custom types

PascalCase strings reference value objects, entities, or other domain types:

```ruby
attribute :address, "Address"     # references a value object
attribute :status, "OrderStatus"  # references a custom type
```

### Attribute options

```ruby
attribute :name, String                          # required, no default
attribute :status, String, default: "draft"      # with default
attribute :role, String, enum: ["admin", "user"] # constrained values
attribute :email, String, pii: true              # PII flag
```

---

## Lifecycle

State machine bound to an attribute. Commands trigger transitions
between states.

```ruby
lifecycle :status, default: "draft" do
  transition "SubmitForReview" => "pending"
  transition "ApprovePost" => "published", from: "pending"
  transition "RejectPost" => "rejected", from: "pending"
  transition "ArchivePost" => "archived", from: ["published", "rejected"]
end
```

The `from:` constraint is optional. Without it, the transition is allowed
from any state. With it, the runtime raises an error if the current state
doesn't match.

State predicates are generated automatically:

```ruby
post.draft?      # => true
post.published?  # => false
```

---

## Policy

Reactive policies listen for domain events and trigger commands in response.
Guard policies validate commands before execution.

### Reactive policy

```ruby
# On an aggregate
policy "NotifyChef" do
  on "PlacedOrder"
  trigger "PrepareIngredients"
  async true
  map pizza_id: :pizza_id, quantity: :servings
  defaults priority: "normal"
  condition { |event| event.quantity > 5 }
end

# Cross-aggregate (domain level)
policy "CreateInvoice" do
  on "PlacedOrder"
  trigger "GenerateInvoice"
  map order_id: :reference_id
end
```

### Guard policy

```ruby
policy "MustBeAdmin" do |cmd|
  cmd.role == "admin"
end
```

Referenced from commands with `guarded_by "MustBeAdmin"`.

---

## Validation and Invariants

### Validations (field-level)

```ruby
validation :name, presence: true
validation :email, presence: true, type: String, uniqueness: true
```

### Invariants (aggregate-level business rules)

```ruby
invariant "price must be positive" do
  price > 0
end

invariant "end date after start date" do
  end_date > start_date
end
```

Value objects and entities also support invariants:

```ruby
value_object "Money" do
  attribute :amount, Float
  attribute :currency, String
  invariant "amount must be non-negative" do
    amount >= 0
  end
end
```

---

## Port

Access control per role. Restricts which operations are allowed.

```ruby
port :admin do
  allow :find, :all, :create_pizza, :update_pizza, :delete
end

port :guest, [:find, :all]

port :customer do
  allow :find, :all, :place_order
end
```

---

## Query and Scope

### Queries (custom logic)

```ruby
query "ByDescription" do |desc|
  where(description: desc)
end

query "Classics" do
  where(style: "Classic").order(:name)
end
```

### Scopes (named filters)

```ruby
# Hash scope (static conditions)
scope :active, status: "active"
scope :premium, tier: "premium"

# Lambda scope (parameterized)
scope :by_price, ->(min) { { price: Hecks::Querying::Operators::Gte.new(min) } }
```

### Indexes

```ruby
index :email, unique: true
index :name, :status           # composite index
```

---

## Specification

Reusable predicates for filtering or workflow branching.

```ruby
specification "HighRisk" do |loan|
  loan.principal > 50_000
end

specification "Overdue" do |invoice|
  invoice.due_date < Date.today && invoice.status == "unpaid"
end
```

Used in workflows:

```ruby
workflow "LoanApproval" do
  branch do
    when_spec("HighRisk") { step "ManualReview" }
    otherwise { step "AutoApprove" }
  end
end
```

---

## Booting

### Standalone app

```ruby
# Boot from a directory containing hecks_domain.rb
app = Hecks.boot(__dir__)

# With SQL persistence
app = Hecks.boot(__dir__, adapter: :sqlite)
```

### Rails

```ruby
# config/initializers/hecks.rb
Hecks.configure do |config|
  config.domain_path = Rails.root.join("app/domain")
  config.adapter = :memory
end
```

### Running commands

```ruby
pizza = Pizza.create(name: "Margherita", description: "Classic")
Pizza.find(pizza.id)
Pizza.all
Pizza.count
Pizza.by_description("Classic")
```

### Events

```ruby
app.on("CreatedPizza") do |event|
  puts "#{event.name} created at #{event.occurred_at}"
end

app.events  # => array of all published events
```
