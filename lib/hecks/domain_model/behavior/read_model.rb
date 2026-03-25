# Hecks::DomainModel::Behavior::ReadModel
#
# Intermediate representation of a read model — an event-driven projection
# that maintains a denormalized view of domain state. Each read model has a
# name and a hash of projections mapping event names to transformation procs.
#
# Part of the DomainModel IR layer. Built by ReadModelBuilder, consumed by
# ReadModelWiring at runtime to create queryable projections.
#
#   rm = ReadModel.new(
#     name: "OrderSummary",
#     projections: { "PlacedOrder" => proc { |event, state| ... } }
#   )
#   rm.name         # => "OrderSummary"
#   rm.projections  # => { "PlacedOrder" => #<Proc> }
#
module Hecks
  module DomainModel
    module Behavior
      class ReadModel
        attr_reader :name, :projections

        def initialize(name:, projections: {})
          @name = name
          @projections = projections
        end
      end
    end
  end
end
