# Hecks::DomainModel::Structure::Entity
#
# Intermediate representation of a sub-entity within an aggregate. Entities
# have identity (UUID), are mutable, and use identity-based equality -- unlike
# value objects which are immutable and compared by attributes.
#
# Part of the DomainModel IR layer. Built by EntityBuilder and consumed by
# EntityGenerator to produce classes that include Hecks::Model.
#
#   entity = Entity.new(
#     name: "LedgerEntry",
#     attributes: [Attribute.new(name: :amount, type: Float)],
#     invariants: [Invariant.new(message: "amount positive", block: proc { amount > 0 })]
#   )
#   entity.name        # => "LedgerEntry"
#   entity.attributes  # => [#<Attribute ...>]
#
module Hecks
  module DomainModel
    module Structure
    class Entity
      attr_reader :name, :attributes, :invariants

      def initialize(name:, attributes: [], invariants: [])
        @name = name
        @attributes = attributes
        @invariants = invariants
      end
    end
    end
  end
end
