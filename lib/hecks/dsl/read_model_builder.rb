# Hecks::DSL::ReadModelBuilder
#
# DSL builder for read model definitions. Collects event projections
# and builds a DomainModel::Behavior::ReadModel. Each projection maps
# an event name to a proc that transforms state.
#
#   builder = ReadModelBuilder.new("OrderSummary")
#   builder.project("PlacedOrder") { |event, state| state.merge(total: event.quantity) }
#   rm = builder.build  # => #<ReadModel name="OrderSummary" ...>
#
module Hecks
  module DSL
    class ReadModelBuilder
      def initialize(name)
        @name = name
        @projections = {}
      end

      def project(event_name, &block)
        @projections[event_name.to_s] = block
      end

      def build
        DomainModel::Behavior::ReadModel.new(
          name: @name,
          projections: @projections
        )
      end
    end
  end
end
