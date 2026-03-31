# Pizzas Domain Glossary

## Pizza

A Pizza has a name (String).
A Pizza has a style (String).
A Pizza has a price (Float).
You can create a Pizza with name, style, and price. When this happens, a Pizza is created. (command)
You can look up Pizzas by classics. (query)

## Order

An Order has a quantity (Integer).
You can place an Order with quantity. When this happens, an Order is placed. (command)

## Relationships

An Order references a Pizza.
