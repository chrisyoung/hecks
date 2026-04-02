# Implicit DSL in REPL

Natural language domain editing in the Hecks workshop.

## Usage

```ruby
# In the hecks workshop (hecks console):
say "add an aggregate called Pizza"
# => Pizza aggregate created

say "give Pizza a name attribute of type String"
# => Added name (String) to Pizza

say "add a command CreatePizza to Pizza"
# => Added command CreatePizza to Pizza

say "Pizza references Order"
# => Added reference from Pizza to Order

say "validate"
# Runs domain validation

say "describe"
# Shows domain structure

say "build"
# Builds the domain

say "save"
# Saves to Bluebook
```

## Supported Phrases

| Phrase Pattern | Action |
|---|---|
| `add an aggregate called X` | Creates aggregate X |
| `give X a Y attribute of type Z` | Adds attribute Y:Z to aggregate X |
| `add command Cmd to X` | Adds command Cmd to aggregate X |
| `X references Y` | Adds reference from X to Y |
| `remove X` | Removes aggregate X |
| `validate` | Validates the domain |
| `build` | Builds the domain |
| `save` | Saves to Bluebook file |
| `describe` / `show` / `preview` | Shows domain structure |

## Graceful Degradation

Unrecognized phrases return nil with a suggestion:

```ruby
say "make me a sandwich"
# I didn't understand: make me a sandwich
# Try: 'add an aggregate called Pizza', 'give Pizza a name attribute'
```

## Alias

`domain_edit` is an alias for `say`:

```ruby
domain_edit "add an aggregate called Order"
```
