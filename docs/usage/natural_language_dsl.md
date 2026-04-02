# Natural Language DSL

Use `say` in the Hecks REPL to describe domain changes in plain English.
The LLM translates your request into DSL operations and applies them.

## Setup

Set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

## Usage

```ruby
# Start the workshop
hecks console Pizzas

# Use natural language to build your domain
say "create a Pizza aggregate with name and description attributes"
#   Plan:
#     Create aggregate Pizza
#     Add name (String) to Pizza
#     Add description (String) to Pizza
#     Add command CreatePizza to Pizza

say "add a price as a Float to Pizza"
#   Plan:
#     Add price (Float) to Pizza

say "add an Order aggregate that references Pizza"
#   Plan:
#     Create aggregate Order
#     Add command CreateOrder to Order
#     Add reference_to Pizza on Order

# Mix natural language with direct DSL
Pizza.lifecycle :status, default: "available"
say "add a transition to mark a pizza as sold out"
#   Plan:
#     Add transition MarkSoldOut => sold_out on Pizza
```

## How It Works

1. Your text is sent to the Anthropic API with the current domain state as context
2. The LLM returns structured operations (add_attribute, add_command, etc.)
3. The plan is printed so you can see what will happen
4. Operations are applied to the workshop session

## Conversation Context

The interpreter maintains conversation history within a session, so follow-up
requests understand prior context:

```ruby
say "create a Customer aggregate"
say "give it a name and email"  # knows "it" means Customer
```

## Without an API Key

If `ANTHROPIC_API_KEY` is not set, `say` prints a helpful message:

```ruby
say "add a name to Pizza"
# => Natural language requires ANTHROPIC_API_KEY. Set it and try again.
```

All other REPL features continue to work normally.
