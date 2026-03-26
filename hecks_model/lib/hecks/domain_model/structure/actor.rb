module Hecks
  module DomainModel
    module Structure

    # Hecks::DomainModel::Structure::Actor
    #
    # Represents a user role or persona that issues commands. Captured during
    # Event Storming as small yellow stickies -- the people or systems that
    # initiate actions in the domain.
    #
    # Part of the DomainModel IR layer. Does not generate code -- serves as
    # metadata for documentation and access control planning.
    #
    #   actor = Actor.new(name: "Customer")
    #   actor.name  # => "Customer"
    #
    class Actor
      # @return [String] the name of this actor role (e.g., "Customer", "Admin", "Warehouse Staff")
      attr_reader :name

      # Creates a new Actor.
      #
      # @param name [String] the human-readable name of the actor role. This should
      #   correspond to a persona identified during Event Storming -- the person or
      #   system role that initiates commands in the domain.
      #
      # @return [Actor] a new Actor instance
      def initialize(name:)
        @name = name
      end
    end
    end
  end
end
