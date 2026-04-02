# AI Domain Review

AI-powered domain model review with structured DDD feedback.

## CLI Usage

```bash
# Review current domain (local fallback if no API key)
hecks review

# Review a specific domain
hecks review --domain examples/pizzas

# JSON output
hecks review --format json
```

## Output

```
Domain Review: Pizzas (local -- set ANTHROPIC_API_KEY for AI review)
Score: 8/10

Strengths:
  + Domain has 2 well-defined aggregates
  + All aggregates have commands
  + Uses value objects for composition

Improvements:
  [validation] Order.customer_name is a generic attribute name
    -> Rename to describe the attribute's purpose
```

## AI-Powered Review

Set `ANTHROPIC_API_KEY` to get LLM-powered feedback:

```bash
export ANTHROPIC_API_KEY=your-key
hecks review
```

The AI review analyzes:
1. Naming clarity and ubiquitous language
2. Aggregate boundary sizing and cohesion
3. Missing domain concepts
4. Reference topology and coupling
5. Command/event design patterns

## Programmatic Usage

```ruby
domain = Hecks.domain("Pizzas") { ... }

# Local review (no API key needed)
reviewer = Hecks::AI::DomainReviewer.new(domain)
review = reviewer.review
review[:overall_score]  # => 8
review[:strengths]      # => ["Domain has 2 well-defined aggregates", ...]
review[:improvements]   # => [{ area: "naming", description: "...", suggestion: "..." }]
```
