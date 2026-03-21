# Pizza Ordering
# ================

## Bounded Context: Ordering
## -------------------------

Actor: Customer
  |
  v
Command: [Place Order]
  Aggregate: (Order)
  ReadModel: <Menu & Availability>
  |
  v
Event: >>Order Placed<<
  |
  +---> Policy: {When Order Placed, Reserve Inventory}
  |       |
  |       v
  |     Command: [Reserve Stock]
  |       Aggregate: (Inventory)
  |       |
  |       v
  |     Event: >>Stock Reserved<<
  |
  +---> Policy: {When Order Placed, Start Payment}
          |
          v
        Command: [Process Payment]
          Aggregate: (Payment)
          External: [[Stripe]]
          |
          +--> Event: >>Payment Succeeded<<
          |      |
          |      v
          |    Policy: {When Payment Succeeded, Confirm Order}
          |      |
          |      v
          |    Command: [Confirm Order]
          |      Aggregate: (Order)
          |      |
          |      v
          |    Event: >>Order Confirmed<<
          |
          +--> Event: >>Payment Failed<<
                 |
                 v
               Policy: {When Payment Failed, Release Inventory}
                 |
                 v
               Command: [Release Stock]
                 Aggregate: (Inventory)
                 |
                 v
               Event: >>Stock Released<<


## Bounded Context: Fulfillment
## ----------------------------

Event: >>Order Confirmed<<
  |
  v
Policy: {When Order Confirmed, Begin Preparation}
  |
  v
Command: [Start Preparation]
  Aggregate: (Kitchen Ticket)
  |
  v
Event: >>Preparation Started<<

Actor: Cook
  |
  v
Command: [Mark Ready]
  Aggregate: (Kitchen Ticket)
  |
  v
Event: >>Order Ready<<
  |
  v
Policy: {When Order Ready, Notify Customer}
  |
  v
Command: [Send Notification]
  Aggregate: (Kitchen Ticket)
  External: [[SMS Gateway]]
  |
  v
Event: >>Customer Notified<<


# ===== LEGEND =====
#
#   >>Event Name<<        Domain Event       (orange sticky)
#   [Command Name]        Command            (blue sticky)
#   (Aggregate)           Aggregate          (yellow sticky)
#   {When X, Do Y}        Policy/Process     (lilac sticky)
#   <Read Model>          Read Model         (green sticky)
#   [[System]]            External System    (pink sticky)
#   Actor: Name           Actor/Role         (small yellow sticky)
#   !!Problem!!           Hotspot            (red sticky)
#
#   |, v, +-->            Flow / causality
#   # comment             Context boundary or note
