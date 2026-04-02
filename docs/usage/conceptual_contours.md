# Conceptual Contours

Validation rules that warn about aggregate complexity and structural issues.

## TooManyAttributes (8+)

```ruby
# Warning triggered:
aggregate "Customer" do
  attribute :first_name, String
  attribute :last_name, String
  attribute :email, String
  attribute :phone, String
  attribute :street, String
  attribute :city, String
  attribute :state, String
  attribute :zip, String    # 8th attribute triggers warning
end

# Fix: extract Address value object
aggregate "Customer" do
  attribute :first_name, String
  attribute :last_name, String
  attribute :email, String
  attribute :phone, String
  value_object("Address") do
    attribute :street, String
    attribute :city, String
    attribute :state, String
    attribute :zip, String
  end
end
```

## TooManyValueObjects (5+)

Warns when an aggregate contains 5 or more value objects. Consider splitting.

## MissingLifecycle

```ruby
# Warning: status attribute without lifecycle
aggregate "Task" do
  attribute :status, String
end

# Fix: add lifecycle
aggregate "Task" do
  attribute :status, String, default: "open" do
    transition "CompleteTask" => "done"
  end
end
```

## CohesionAnalysis

Warns when commands touch disjoint sets of attributes (score < 0.3).

## GodAggregate

Warns when 2+ of these thresholds are exceeded:
- 6+ attributes
- 6+ commands
- 3+ value objects

## Running

```bash
hecks validate
```
