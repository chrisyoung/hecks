require_relative "aggregate_builder/behavior_methods"
require_relative "aggregate_builder/constraint_methods"
require_relative "aggregate_builder/query_methods"
require_relative "aggregate_builder/implicit_syntax"

module Hecks
  module DSL

    # Hecks::DSL::AggregateBuilder
    #
    # DSL builder for aggregate definitions. Collects attributes, value objects,
    # commands, policies, validations, invariants, scopes, ports, and queries,
    # then builds a DomainModel::Structure::Aggregate. Automatically infers
    # domain events from commands.
    #
    #   builder = AggregateBuilder.new("Pizza")
    #   builder.attribute :name, String
    #   builder.command("CreatePizza") { attribute :name, String }
    #   builder.scope :large, size: "L"
    #   agg = builder.build
    #
    class AggregateBuilder
      include AttributeCollector
      include BehaviorMethods
      include ConstraintMethods
      include QueryMethods
      include ImplicitSyntax

      attr_reader :attributes, :commands, :value_objects, :entities,
                  :policies, :validations, :invariants, :scopes, :ports,
                  :queries, :subscribers, :indexes, :specifications

      def initialize(name)
        @name = name
        @attributes = []
        @value_objects = []
        @entities = []
        @commands = []
        @policies = []
        @validations = []
        @invariants = []
        @scopes = []
        @ports = {}
        @queries = []
        @subscribers = []
        @indexes = []
        @specifications = []
        @lifecycle = nil
        @versioned = false
        @attachable = false
        @metadata = {}
      end

      def versioned
        @versioned = true
      end

      def attachable
        @attachable = true
      end

      # Define a nested value object within this aggregate.
      #
      # @param name [String] the value object type name
      # @yield block evaluated in ValueObjectBuilder context
      # @return [void]
      def value_object(name, &block)
        builder = ValueObjectBuilder.new(name)
        builder.instance_eval(&block) if block
        @value_objects << builder.build
      end

      # Define a nested entity within this aggregate.
      #
      # @param name [String] the entity type name
      # @yield block evaluated in EntityBuilder context
      # @return [void]
      def entity(name, &block)
        builder = EntityBuilder.new(name)
        builder.instance_eval(&block) if block
        @entities << builder.build
      end

      def ref(name) = reference_to(name)

      # Build the Aggregate IR object, inferring events from commands.
      #
      # @return [DomainModel::Structure::Aggregate]
      def build
        events = infer_events

        DomainModel::Structure::Aggregate.new(
          name: @name, attributes: @attributes,
          value_objects: @value_objects, entities: @entities,
          commands: @commands, events: events, policies: @policies,
          validations: @validations, invariants: @invariants,
          scopes: @scopes, ports: @ports, queries: @queries,
          subscribers: @subscribers, indexes: @indexes,
          specifications: @specifications, lifecycle: @lifecycle,
          versioned: @versioned, attachable: @attachable,
          metadata: @metadata
        )
      end

      private

      def infer_events
        aggregate_id_attr = DomainModel::Structure::Attribute.new(name: :aggregate_id, type: String)
        @commands.map do |command|
          event_attrs = [aggregate_id_attr] + command.attributes.dup
          @attributes.each do |agg_attr|
            next if event_attrs.any? { |a| a.name == agg_attr.name }
            event_attrs << agg_attr
          end
          DomainModel::Behavior::DomainEvent.new(
            name: command.inferred_event_name,
            attributes: event_attrs
          )
        end
      end
    end
  end
end
