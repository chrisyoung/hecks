# Hecks::DomainModel::ValueObject
#
# Intermediate representation of a DDD value object -- an immutable object
# defined entirely by its attributes, with no identity. Value objects can
# also carry invariants (runtime constraints).
#
# Part of the DomainModel IR layer. Built by ValueObjectBuilder and consumed
# by ValueObjectGenerator to produce frozen, equality-by-value classes.
#
#   vo = ValueObject.new(
#     name: "Address",
#     attributes: [Attribute.new(name: :street, type: String)],
#     invariants: [{ message: "street required", block: proc { !street.nil? } }]
#   )
#   vo.name        # => "Address"
#   vo.invariants  # => [{message: "street required", block: #<Proc>}]
#
module Hecks
  module DomainModel
    class ValueObject
      attr_reader :name, :attributes, :invariants

      def initialize(name:, attributes: [], invariants: [])
        @name = name
        @attributes = attributes
        @invariants = invariants
      end
    end
  end
end
