# Hecks::DomainModel::Aggregate
#
# Intermediate representation of a DDD aggregate -- the core building block
# of a Hecks domain. Groups a root entity with its value objects, commands,
# events, policies, validations, and invariants.
#
# Built by the DSL layer (AggregateBuilder) and consumed by the Generators
# to produce domain gem source code.
#
#   agg = Aggregate.new(
#     name: "Pizza",
#     attributes: [Attribute.new(name: :name, type: String)],
#     commands: [Command.new(name: "CreatePizza", attributes: [...])],
#     events: [DomainEvent.new(name: "CreatedPizza", attributes: [...])]
#   )
#
module Hecks
  module DomainModel
    module Structure
    class Aggregate
      attr_reader :name, :attributes, :value_objects, :commands,
                  :events, :policies, :validations, :invariants, :scopes, :ports, :queries

      def initialize(name:, attributes: [], value_objects: [], commands: [],
                     events: [], policies: [], validations: [], invariants: [],
                     scopes: [], ports: {}, queries: [])
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
      end

    end
    end
  end
end
