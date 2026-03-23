# Hecks::DSL::AggregateBuilder
#
# DSL builder for aggregate definitions. Collects attributes, value objects,
# commands, policies, validations, and invariants, then builds a
# DomainModel::Aggregate. Automatically infers domain events from commands.
#
# The workhorse of the DSL layer -- used inside domain, context, and session
# blocks to define aggregate roots.
#
#   builder = AggregateBuilder.new("Pizza")
#   builder.attribute :name, String
#   builder.command("CreatePizza") { attribute :name, String }
#   builder.validation :name, presence: true
#   agg = builder.build  # => #<Aggregate name="Pizza" ...>
#
module Hecks
  module DSL
    class AggregateBuilder
      include AttributeCollector

      attr_reader :attributes, :commands, :value_objects, :policies, :validations, :invariants, :scopes, :ports, :queries

      def initialize(name)
        @name = name
        @attributes = []
        @value_objects = []
        @commands = []
        @policies = []
        @validations = []
        @invariants = []
        @scopes = []
        @ports = {}
        @queries = []
      end

      def value_object(name, &block)
        builder = ValueObjectBuilder.new(name)
        builder.instance_eval(&block) if block
        @value_objects << builder.build
      end

      def command(name, &block)
        builder = CommandBuilder.new(name)
        builder.instance_eval(&block) if block
        @commands << builder.build
      end

      def policy(name, &block)
        builder = PolicyBuilder.new(name)
        builder.instance_eval(&block) if block
        @policies << builder.build
      end

      def validation(field, rules)
        @validations << DomainModel::Validation.new(field: field, rules: rules)
      end

      def invariant(message, &block)
        @invariants << DomainModel::Invariant.new(message: message, block: block)
      end

      def scope(name, conditions_or_lambda = nil, &block)
        conditions = block || conditions_or_lambda
        @scopes << DomainModel::Scope.new(name: name, conditions: conditions)
      end

      def query(name, &block)
        @queries << DomainModel::Query.new(name: name, block: block)
      end

      def port(name, &block)
        port_builder = PortBuilder.new(name)
        port_builder.instance_eval(&block) if block
        @ports[name] = port_builder.build
      end

      def build
        events = infer_events

        DomainModel::Aggregate.new(
          name: @name,
          attributes: @attributes,
          value_objects: @value_objects,
          commands: @commands,
          events: events,
          policies: @policies,
          validations: @validations,
          invariants: @invariants,
          scopes: @scopes,
          ports: @ports,
          queries: @queries
        )
      end

      private

      def infer_events
        @commands.map do |command|
          DomainModel::DomainEvent.new(
            name: command.inferred_event_name,
            attributes: command.attributes
          )
        end
      end
    end
  end
end
