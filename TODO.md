## For Presentation
* Generate Active Record Adapter
* Fix Update
* Event Port
* Make a gem out of the hexagon
* to_h method on commands
* Update Documentation
* Only use invariants (move schema out of hexagon)

## Next Actions
* Dockerize
* Fix Tests
* Factory for building toppings in pizza
* Rename use cases to commands
* CRUD Commands should generate explicitly
* Value Store (Service?)
* Generator to create config.ru file
* Server gem
* Errors on Update
* CouchDB Persistence Adapter
* Domain Console

## Challenges:
* Remove all if statements

## Start Documenting

### Modules:

#### Your Domain is the root hexagon
PizzaServer

#### Hecks modules are equivalent to DDD aggregates
PizzaServer::Pizzas

#### Invariants are declarative and are returned by command objects.  They can
#### easilly be used as a documentatoin to build validations.  You can use the
PizzaServer::Pizzas::Invariants

#### Commands

#### Commands are equivalent to a hexagonal "driver" port, they are the application
#### ring and are generaly intended to be used create clients for your Hexagon.
PizzaServer::Pizzas::Commands::Create
PizzaServer::Pizzas::Commands::Update
PizzaServer::Pizzas::Commands::Delete

#### Queries
PizzaServer::Pizzas::Queries::PizzaByID
PizzaServer::Pizzas::Queries::Pizzas

#### Drivers (Equivalent to Hexagonal "left port" or "driver port")
PizzaServer::Drivers::HTTP
PizzaServer::Drivers::JSON

#### Clients (Equivalent to hexagonal "right port" or "driven port")
PizzaServer::Repositories::SQL
PizzaServer::Repositories::CouchBase
#### Example