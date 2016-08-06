# Heckson

Use Heckson to generate hexagons using many of the concepts and patterns presented in
Domain Driven Design.

## Domain Driven Design Concepts

Aggregates
Entities
Values
Repositories
Commands

## Developing Domains with Heckson

### Draw a domain
```
┌──────────────────────────────────────────────────────────────────────┐  
│ Domain                                                               │  
│                                                                      │██
│  ╔══════════════════════════════════════════════════════════════╗    │██
│  ║ Pizzas                                                       ║    │██
│  ║    ┌────────┐                                                ║░░  │██
│  ║ ┌──┤Pizza   ├──┐  ┌────────────────────────────────────────┐ ║░░  │██
│  ║ │..│        │..│  │                Usecases                │ ║░░  │██
│  ║ │..│        │..│  │ ┌─────────────────────────────────────┐│ ║░░  │██
│  ║ │..│        │..│  │ │    CreateAPizza(name, toppings)     ││ ║░░  │██
│  ║ │..└────────┘..│  │ ├─────────────────────────────────────┤│ ║░░  │██
│  ║ │.......*......│  │ │ UpdateAPizza(pizza_id, attributes)  ││ ║░░  │██
│  ║ │.......┃......│  │ ├─────────────────────────────────────┤│ ║░░  │██
│  ║ │.......▼......│  │ │       DeleteAPizza(pizza_id)        ││ ║░░  │██
│  ║ │..┌────────┐..│  │ └─────────────────────────────────────┘│ ║░░  │██
│  ║ │..│Topping │..│  └────────────────────────────────────────┘ ║░░  │██
│  ║ │..│        │..│  ┌────────────────────────────────────────┐ ║░░  │██
│  ║ │..│        │..│  │                Queries                 │ ║░░  │██
│  ║ │..│        │..│  │ ┌─────────────────────────────────────┐│ ║░░  │██
│  ║ │..└────────┘..│  │ │         GetAPizza(pizza_id)         ││ ║░░  │██
│  ║ │..............│  │ └─────────────────────────────────────┘│ ║░░  │██
│  ║ └──────────────┘  └────────────────────────────────────────┘ ║░░  │██
│  ║                                                              ║░░  │██
│  ╚══════════════════════════════════════════════════════════════╝░░  │██
│    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │██
│    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │██
│                                                                      │██
│                                                                      │██
└──────────────────────────────────────────────────────────────────────┘██
  ████████████████████████████████████████████████████████████████████████
  ████████████████████████████████████████████████████████████████████████
```

## How to Meditate

### Method:

Pay attention and relax

### Notes:

Everything happens in the moment
"The moment" is another way of saying "Now".

You are seeing, hearing, smelling, tasting, and breathing right now.
Thoughts are a signal that you are not in the moment.

Pay attention and relax. In the moment, everything is the truth as it is.
Future thinking brings fear, Past thinking brings regret.

So Just right now, what is the truth?
In the morning, it is bright. In the evening, it is dark.
