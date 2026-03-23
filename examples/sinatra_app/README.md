# Sinatra Example

Generated from the pizzas domain with `hecks generate:sinatra --domain pizzas_domain`.

Every route in `app.rb` comes from the domain DSL. Edit it to add auth, middleware, custom endpoints — it's your app now.

## Running

```bash
cd examples/sinatra_app
bundle install
ruby app.rb
```

## Routes

```
GET    /pizzas                         — all pizzas
GET    /pizzas/:id                     — find by ID
POST   /pizzas                         — create (JSON body)
DELETE /pizzas/:id                     — delete
GET    /pizzas/by_description?desc=... — named lookup
GET    /orders                         — all orders
GET    /orders/pending                 — pending orders
```
