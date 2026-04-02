# = Hecks::DomainModel::Behavior::UpcasterDeclaration
#
# IR node representing a domain-level event upcaster declaration.
# Captures the event type, source version, target version, and the
# transform block that converts event data between versions.
#
#   decl = UpcasterDeclaration.new(
#     event_type: "CreatedPizza", from: 1, to: 2,
#     transform: ->(data) { data.merge("description" => "") }
#   )
#
module Hecks
  module DomainModel
    module Behavior
      class UpcasterDeclaration
        # @return [String] the event type name
        attr_reader :event_type

        # @return [Integer] the source schema version
        attr_reader :from

        # @return [Integer] the target schema version
        attr_reader :to

        # @return [Proc] the transform block
        attr_reader :transform

        def initialize(event_type:, from:, to:, transform:)
          @event_type = event_type
          @from = from
          @to = to
          @transform = transform
        end
      end
    end
  end
end
