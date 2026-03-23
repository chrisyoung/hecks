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
module Hecks
  module DomainModel
    module Structure
    class Actor
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end
    end
  end
end
