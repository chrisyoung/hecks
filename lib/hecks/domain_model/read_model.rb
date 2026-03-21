# Hecks::DomainModel::ReadModel
#
# Represents a read model (data view) needed by a command to make decisions.
# Captured during Event Storming as green stickies -- the information a user
# needs to see before issuing a command.
#
# Part of the DomainModel IR layer. Does not generate code -- serves as
# metadata for documentation and domain understanding.
#
#   read_model = ReadModel.new(name: "Menu & Availability")
#   read_model.name  # => "Menu & Availability"
#
module Hecks
  module DomainModel
    class ReadModel
      attr_reader :name

      def initialize(name:)
        @name = name
      end
    end
  end
end
