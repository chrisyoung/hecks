[![Code Climate](https://codeclimate.com/github/chrisyoung/hecks/badges/gpa.svg)](https://codeclimate.com/github/chrisyoung/hecks)[ ![Test Coverage](https://codeclimate.com/github/chrisyoung/hecks/badges/coverage.svg)](https://codeclimate.com/github/chrisyoung/hecks/coverage) [![Gem Version](https://badge.fury.io/rb/hecks.svg)](https://badge.fury.io/rb/hecks)

# What the Hecks?
**Use Hecks to build scalable software that matches the language of your
business.**

Hecks uses a workflow borrowed from Domain Driven Design, ie: build a domain
model to represent the Ubiquitous language of your business.  Hecks provides the
tools to iteratively generate this domain as code

# Why the hecks?
* You want to go fast
* You want your code to match the language of your business
* You want to eliminate head-gap across all departments
* You want to Deliver your product continuously
* You want to build scalable software
* You want your code to get better over time
* You want your tests to be fast and clear
* You want to stop writing boilerplate
* You want to be able to easily deploy solutions across multiple technologies
* You want to have great documentation but remain agile
* You want a framework that is ea sy to build microservices with
* You want to stop bleeding Business Logic across boundaries
* You want to stop writing code to protect against row locking
* You want to separate technology decisions from how you describe your business
* You want documentation that works for all departments
* You want to cut out the work it takes to adapt your domain to production environments
* You want to shim your legacy code to a modern understanding of what your company does
* You want to continue to develop Iteratively
* You want to understand the entire context of your business
* You want a solution to consistently organizing your code

# How the Hecks?
Rigorously develop the model of the language of your businiess
* Iteratively Develop a Domain Model
* Write or use existing Hecks::Adapters to cover technical use cases like
`Hecks::Adapters::HTTPResourceServer` and `Hecks::Package::Lambda`
* Use the adapters to accomplish Business use cases
* Verify, Deliver, and Iterate

# Usage
## Story
As a client, I should be able to create a Pizza over http

## Tasks:
* Install Hecks
* Build a PizzaBuilder Domain,
* Generate configuration
* Run the HTTP Resource Server

## Install
Install Hecks using Ruby Gems

	$ gem install hecks

Verify the installation

	$ hecks help

	hecks commands:
	hecks console         # REPL with domain helpers
	hecks generate        # generate
	hecks help [COMMAND]  # Describe available commands or one specific command
	hecks new             # Create a new Domain
	hecks package         # package

## Create a Domain file in an empty project directory:
**Add a Domain file to your project that formally describes the model you want
to build.**

PizzaBuilder is a ridiculously simplified domain model that Hecks uses as an
example Domain across the documentation and tests.

	Hecks::Domain::DomainBuilder.build "pizza_builder" do |pizza_builder|
		pizza_builder.module 'Pizzas' do |pizzas|
		  pizzas.head("Pizza").attributes('name:string', 'description:string', 'toppings:[topping]')
		  pizzas.value("Topping").attributes('name:string')
		end

		pizza_builder.module 'Orders' do |orders|
		  orders.head("Order").attributes('line_items:[LineItem]')
		  orders.value("LineItem").attributes('pizza_name:value', 'quantity:Value', 'price:Value')
		end
	end

Generate the domain model

	$ hecks new

Hecks generates the Objects that you'll use to interact with the domain, such
as:

	PizzaBuilder::Domain::Pizzas::Pizza
	PizzaBuilder::Domain::Pizzas::Topping
	PizzaBuilder::Domain::Pizzas::Chef

## Run the HTTPResourceServer
**Run a web server that gives access to Pizzas and Orders over HTTP.**

Expect to have routes to CRUD methods for all of your Domain Modules, such as:

	Create: POST /pizzas
	Read: GET /pizzas/1
	Update: PUT /pizzas
	Destroy: DELETE /pizzas/1

These methods are also available on the Orders Domain Module

Generate the resource server configuration

	$ hecks generate:resource_server

Start a rackup web server

	$ rackup config.ru

Use curl to create a pizza

	$ curl -H "Content-Type: application/json" /
	-d '{"name": "white", "description":"yummy", "toppings": [{"name":"pepperoni"}]}' /
	localhost:9292/pizzas

## Access your domain from the command line
The command line adapter is currently implemented as a 2.2.2 traveling ruby
package.  Hecks provides the means to build that package.

	$ hecks package binary
	$ pizza_builder pizzas create '{"name":"White Pizza","description":"white sauce and chicken","chef":{"name":"Chef Ramsey"},"toppings":[{"name":"chicken"}]}'

## Access your domain from a Ruby Console
Move into your domain's directory (the one creared with hecks new)

	$ hecks console
	:001 > pp app[:pizzas].create({name: 'White Pizza' ... }]})

## Deploy your domain to AWS Lambda
Hecks is friends with serverless to generate a deployable function.  Here's how
to see if it worlks locally:

Make a deployable Lambda package

	$ hecks package lambda

See it work locally

	$ DATABASE_URL='mysql2://root:password@localhost/pizza_builder_test' serverless invoke local -f pizza_builder -d '{"module": "Pizzas", "method": "create", "data": {"name":"White Pizza","description":"white sauce and chicken","chef":{"name":"Chef Ramsey"},"toppings":[{"name":"chicken"}]}}'

# Domain Driven Design (DDD) Primer
This primer contains the design principles used to build Hecks Domains
like PizzaBuilder.  These are a small sub-section of patterns described in
Domain Driven Design by Eric Evans.  Designing the Ubiquitous Language of your
Domain with these concepts will allow you to use Hecks to generate your domain
and use adapters like `Hecks::Adapters::ResourceServer` and
`Hecks::Adapters::SQLDatabase`.

## Domain Modules
Hecks treats Domain Modules and Aggregates interchangeably.  For example, `PizzaBuilder::Pizzas` and `PizzaBuilder::Orders` are both Domain modules.  These
modules contain the actual objects that can be used to interact with the domain,
such as `Pizzas::Pizza`, `Pizzas::Chef` and `Orders::LineItem`.

## Aggregates
An Aggregate is always accessed through a single "head" object.  A head is
always an entity.  You can find out the head object like so:
	`PizzaBuilder::Pizzas#head`
In this case, the Aggregate is Pizzas and the `#head` method will return
`PizzaBuilder::Pizzas::Pizza`.

## Entities
An Entity is a domain object that you track over time.  Entities rely on unique
ids.  For instance, a person can change their name but retain their identity
(for example, a social security number). Entities are often, but not always,
the heads of Aggregates.  A Pizza is an example of an entity, you can change
its name but its identity will remain the same.

## Values
A value object does not have an identity that persists over time.  For instance,
a topping in the PizzaBuilder domain is a value.  "Pepperoni" will always be
"Pepperoni", it is not expected to ever change its name to "Mushroom".  Value
objects can be thrown away and replaced on updates with new values without
having to rely on any lifecycle management.

## Repositories
A repository is an abstraction for accessing databases.  In Hecks, repositories
are grouped into Databases.  Databases work like adapters in that you can write
a database adapter to map Hecks Domain operations to specific technologies like
"SQL Server", and "CouchDB".  Out of the box, Hecks repositories support CRUD
operations.  By default all of the domain modules use an "In memory" database.

# Note: On Ruby on Rails
Hecks actually started as a way to introduce Domain Driven Design into Rails,
but there's no need to mix the concepts.  Just import `PizzaBuilder` and
`Hecks::Application` into your Rails project and use them as you see fit.  
There are plans to make the interaction between Hecks and Rails very sweet
(Maybe Hecks Domain as a Rails Engine?)

# Contribute to Hecks
Here are some commands that will be helpful if you would like to develop new
features for Hecks

	$ bash bin/build # Builds and installs the hecks gem locally
	$ hecks bin/ci # run the full test suite for continuous integration
	$ rspec # run the spec suite (fast)
	$ guard # run the tests when you save a file

# Features
* Dev mode if gem isn't installed
* Vernacular (UL) is robust and persists
* No dependencies in the domain
* Tell don't ask
* Build tests around generated examples
* Default In Memory Repository
* Model with OOP
* Technologies are adapted to the domain
* Domain Driven Design
* Hexagonal Architecture
* Generate configurations
* Fast, iterative development through cli
* Adapters access the domain through Hecks::Application
* Operations are accomplished through command objects
* Query attaches to a separate database

# Constraints
* Drive tests with CI
* No dependencies in the domain (Simple Ruby Objects)
* Use a head entity to do operations on a module, traverse references
