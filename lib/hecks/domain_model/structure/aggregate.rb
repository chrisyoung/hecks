# Hecks::DomainModel::Structure::Aggregate
#
# Intermediate representation of a DDD aggregate -- the core building block
# of a Hecks domain. Groups a root entity with its value objects, commands,
# events, policies, queries, validations, invariants, scopes, and ports.
#
# Built by the DSL layer (AggregateBuilder) and consumed by Generators
# to produce domain gem source code and persistence adapters.
#
#   agg = Aggregate.new(
#     name: "Pizza",
#     attributes: [Attribute.new(name: :name, type: String)],
#     commands: [Command.new(name: "CreatePizza", attributes: [...])],
#     events: [DomainEvent.new(name: "CreatedPizza", attributes: [...])],
#     scopes: [Scope.new(name: :active, conditions: { status: "active" })],
#     ports: { guest: PortDefinition.new(name: :guest, allowed_methods: [:find]) }
#   )
#
module Hecks
  module DomainModel
    module Structure
    class Aggregate
      attr_reader :name, :attributes, :value_objects, :commands,
                  :events, :policies, :validations, :invariants, :scopes, :ports, :queries, :subscribers

      def initialize(name:, attributes: [], value_objects: [], commands: [],
                     events: [], policies: [], validations: [], invariants: [],
                     scopes: [], ports: {}, queries: [], subscribers: [])
        @name = name
        @attributes = attributes
        @value_objects = value_objects
        @commands = commands
        @events = events
        @policies = policies
        @validations = validations
        @invariants = invariants
        @scopes = scopes
        @ports = ports
        @queries = queries
        @subscribers = subscribers
      end

    end
    end
  end
end
