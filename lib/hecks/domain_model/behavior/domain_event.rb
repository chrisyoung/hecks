# Hecks::DomainModel::Behavior::DomainEvent
#
# Intermediate representation of a domain event -- a record that something
# happened. Events are automatically inferred from commands by the
# AggregateBuilder (CreatePizza -> CreatedPizza) and carry the same attributes.
#
# Part of the DomainModel IR layer. Consumed by EventGenerator to produce
# frozen event classes with occurred_at timestamps.
#
#   event = DomainEvent.new(name: "CreatedPizza", attributes: [Attribute.new(name: :name, type: String)])
#   event.name        # => "CreatedPizza"
#   event.attributes  # => [#<Attribute name=:name>]
#
module Hecks
  module DomainModel
    module Behavior
    class DomainEvent
      attr_reader :name, :attributes

      def initialize(name:, attributes: [])
        @name = name
        @attributes = attributes
      end
    end
    end
  end
end
