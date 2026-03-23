# Hecks::DSL::CommandBuilder
#
# DSL builder for command definitions. Collects attributes, read models,
# external systems, and actors, then builds a DomainModel::Behavior::Command.
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
        @handler = nil
        @read_models = []
        @external_systems = []
        @actors = []
      end

      def handler(&block)
        @handler = block
      end

      def read_model(name)
        @read_models << DomainModel::Structure::ReadModel.new(name: name)
      end

      def external(name)
        @external_systems << DomainModel::Structure::ExternalSystem.new(name: name)
      end

      def actor(name)
        @actors << DomainModel::Structure::Actor.new(name: name)
      end

      def build
        DomainModel::Behavior::Command.new(
          name: @name, attributes: @attributes, handler: @handler,
          read_models: @read_models, external_systems: @external_systems, actors: @actors
        )
      end
    end
  end
end
