# AI Domain Review

AI-powered DDD review of a Hecks domain model. Evaluates aggregate boundaries,
command design, value objects, naming, references, policies, and missing patterns.

## Prerequisites

Set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

Without an API key the command degrades gracefully, returning a stub review
with score 0 and a message to configure the key.

## CLI Usage

Review the domain in the current directory:

```bash
hecks review
```

Review a specific domain:

```bash
hecks review --domain path/to/my_domain
```

JSON output for tooling:

```bash
hecks review --format json
```

Use a different model:

```bash
hecks review --model claude-sonnet-4-20250514
```

### Example Output

```
Reviewing domain: Pizzas...

Score: 7/10
Solid domain model with minor naming improvements needed.

  [SUGGESTION] Pizza (value_objects)
    Consider extracting Topping as a value object with validation.
    => Add a Topping value object with name and amount attributes.

  [WARNING] Order (boundaries)
    Order aggregate references Pizza directly -- consider using an ID reference.
    => Use reference_to(Pizza) to keep aggregate boundaries clean.
```

## MCP Tool

The `review_domain` tool is available in the MCP server:

```
Tool: review_domain
Input: {} (no parameters -- reviews the current session domain)
Output: JSON with overall_score, summary, and findings array
```

## Ruby API

```ruby
require "hecks_ai"

domain = Hecks.last_domain
review = Hecks::AI::DomainReviewer.new(domain).call

puts review[:overall_score]  # => 7
puts review[:summary]        # => "Solid domain model..."

review[:findings].each do |f|
  puts "[#{f[:severity]}] #{f[:target]}: #{f[:message]}"
end
```

## Severity Levels

| Level      | Meaning                                                  |
|------------|----------------------------------------------------------|
| critical   | Violates a core DDD principle, will cause problems       |
| warning    | Suboptimal but functional, fix before model grows        |
| suggestion | Nice-to-have improvement for clarity or expressiveness   |

## Review Categories

- **boundaries** -- aggregate consistency boundaries
- **commands** -- command naming and design
- **value_objects** -- primitive obsession, missing VOs
- **naming** -- ubiquitous language consistency
- **references** -- cross-aggregate coupling
- **policies** -- missing or misconfigured policies
- **missing_patterns** -- lifecycles, specs, services
