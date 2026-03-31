# Shipping Domain Glossary

## Shipment

A Shipment has a pizza (String).
A Shipment has a quantity (Integer).
A Shipment has a status (String).
You can create a Shipment with pizza and quantity. When this happens, a Shipment is created. (command)
You can ship a Shipment with shipment. When this happens, a Shipment is shipped. (command)
You can look up Shipments by ready to ship. (query)
When an Order is placed, the system will create Shipment. (policy)

