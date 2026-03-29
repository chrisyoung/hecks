# Pizzas Domain Glossary

## Pizza

A Pizza has a name (String).
A Pizza has a description (String).
A Pizza has many Toppings.
A Topping is part of a Pizza.
  A Topping has a name (String).
  A Topping has an amount (Integer).
  amount must be positive. (invariant)
You can create a Pizza with name and description. When this happens, a Pizza is created. (command)
You can add a Pizza with pizza id, name, and amount. When this happens, a Topping is added. (command)
You can look up Pizzas by by description. (query)
A Pizza must have a name. (validation)
A Pizza must have a description. (validation)

## Order

An Order has a customer_name (String).
An Order has many OrderItems.
An Order has a status (String).
An OrderItem is part of an Order.
  An OrderItem has a pizza_id (String).
  An OrderItem has a quantity (Integer).
  quantity must be positive. (invariant)
You can place an Order with customer name, pizza id, and quantity. When this happens, an Order is placed. (command)
You can cancel an Order with order id. When this happens, an Order is canceled. (command)
You can look up Orders by pending. (query)
An Order must have a customer_name. (validation)

