# Hecks::DSL::CommandBuilder
#
# DSL builder for command definitions. Collects attributes that represent the
# command's payload, then builds a DomainModel::Command.
#
# Part of the DSL layer, nested under AggregateBuilder. Each command
# automatically gets a corresponding domain event inferred by name.
#
#   builder = CommandBuilder.new("CreatePizza")
#   builder.attribute :name, String
#   builder.attribute :size, String
#   cmd = builder.build  # => #<Command name="CreatePizza" ...>
#   cmd.inferred_event_name  # => "CreatedPizza"
#
module Hecks
  module DSL
    class CommandBuilder
      include AttributeCollector

      attr_reader :attributes

      def initialize(name)
        @name = name
        @attributes = []
      end

      def build
        DomainModel::Command.new(name: @name, attributes: @attributes)
      end
    end
  end
end
