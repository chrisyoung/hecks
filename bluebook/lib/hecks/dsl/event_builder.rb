module Hecks
  module DSL

    # Hecks::DSL::EventBuilder
    #
    # DSL builder for explicit domain event declarations.
    # Used for events not inferred from commands (time-based, external, computed).
    #
    #   builder = EventBuilder.new("PolicyExpired")
    #   builder.attribute :policy_id, String
    #   event = builder.build
    #
    class EventBuilder
      include AttributeCollector

      def initialize(name)
        @name = name
        @attributes = []
        @schema_version = 1
      end

      # Set the schema version for this event.
      #
      #   event "PolicyExpired" do
      #     schema_version 3
      #     attribute :policy_id, String
      #   end
      #
      # @param version [Integer] the current schema version
      # @return [void]
      def schema_version(version)
        @schema_version = version
      end

      def build
        DomainModel::Behavior::DomainEvent.new(
          name: @name,
          attributes: @attributes,
          schema_version: @schema_version
        )
      end
    end
  end
end
