# Hecks::DSL::ValueObjectBuilder
#
# DSL builder for value object definitions. Collects attributes and invariants,
# then builds a DomainModel::Structure::ValueObject. Used inside aggregate blocks.
#
# Part of the DSL layer, nested under AggregateBuilder. The resulting value
# object is embedded within its parent aggregate.
#
#   builder = ValueObjectBuilder.new("Address")
#   builder.attribute :street, String
#   builder.attribute :city, String
#   builder.invariant("street required") { !street.nil? }
#   vo = builder.build  # => #<ValueObject name="Address" ...>
#
module Hecks
  module DSL
    class ValueObjectBuilder
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
        DomainModel::Structure::ValueObject.new(
          name: @name,
          attributes: @attributes,
          invariants: @invariants
        )
      end
    end
  end
end
