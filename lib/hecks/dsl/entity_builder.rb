# Hecks::DSL::EntityBuilder
#
# DSL builder for sub-entity definitions within aggregates. Collects attributes
# and invariants, then builds a DomainModel::Structure::Entity. Entities have
# identity (UUID), are mutable, and use identity-based equality.
#
# Part of the DSL layer, nested under AggregateBuilder. The resulting entity
# is embedded within its parent aggregate.
#
#   builder = EntityBuilder.new("LedgerEntry")
#   builder.attribute :amount, Float
#   builder.attribute :description, String
#   builder.invariant("amount positive") { amount > 0 }
#   entity = builder.build  # => #<Entity name="LedgerEntry" ...>
#
module Hecks
  module DSL
    class EntityBuilder
      include AttributeCollector

      def initialize(name)
        @name = name
        @attributes = []
        @invariants = []
      end

      def invariant(message, &block)
        @invariants << DomainModel::Structure::Invariant.new(message: message, block: block)
      end

      def build
        DomainModel::Structure::Entity.new(
          name: @name,
          attributes: @attributes,
          invariants: @invariants
        )
      end
    end
  end
end
