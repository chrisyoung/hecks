# Multi-Domain Example

Three separate domains sharing one event bus. When an order is placed in the pizzas domain, billing creates an invoice and shipping creates a shipment — automatically, through events.

## Domains

- **pizzas_domain** — Pizza and Order. Placing an order fires `PlacedOrder`.
- **billing_domain** — Invoice. Reacts to `PlacedOrder` with `CreateInvoice`.
- **shipping_domain** — Shipment. Reacts to `PlacedOrder` with `CreateShipment`.

## Running

```bash
ruby -Ilib examples/multi_domain/app.rb
```

## What happens

1. A pizza is created in the pizzas domain
2. An order is placed — fires `PlacedOrder` event
3. Billing reacts — fires `CreatedInvoice` event
4. Shipping reacts — fires `CreatedShipment` event
5. All events are visible in the shared event history

No domain knows about the others. They communicate through events only.
