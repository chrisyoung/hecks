# CommandContract: reference_attribute? and find_self_ref

Centralized self-referencing attribute detection in `CommandContract`.
Replaces the duplicated `end_with?("_id")` + suffix-matching pattern
across 7+ callsites (Ruby, Go, Node generators and spec generators).

## API

```ruby
# Check if an attribute name is a self-referencing foreign key
Hecks::Conventions::CommandContract.reference_attribute?("policy_id", "GovernancePolicy")
# => true

Hecks::Conventions::CommandContract.reference_attribute?("name", "GovernancePolicy")
# => false

# Find the self-ref attribute on a command (nil for create commands)
cmd = domain.aggregates.first.commands.find { |c| c.name == "ActivatePolicy" }
ref = Hecks::Conventions::CommandContract.find_self_ref(cmd, "GovernancePolicy")
ref.name  # => "policy_id"

# Create commands have no self-ref
create_cmd = domain.aggregates.first.commands.find { |c| c.name == "CreatePolicy" }
Hecks::Conventions::CommandContract.find_self_ref(create_cmd, "GovernancePolicy")
# => nil
```

## Multi-word Aggregate Matching

The suffix-matching algorithm handles multi-word aggregate names:

- `policy_id` matches `GovernancePolicy` (via suffix "policy")
- `governance_policy_id` matches `GovernancePolicy` (via full name)
- `pizza_id` matches `Pizza`
