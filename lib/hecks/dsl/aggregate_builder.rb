# Hecks::DSL::AggregateBuilder
#
# DSL builder for aggregate definitions. Collects attributes, value objects,
# commands, policies, validations, invariants, scopes, ports, and queries,
# then builds a DomainModel::Structure::Aggregate. Automatically infers
# domain events from commands.
#
# The workhorse of the DSL layer -- used inside domain, context, and session
# blocks to define aggregate roots.
#
#   builder = AggregateBuilder.new("Pizza")
#   builder.attribute :name, String
#   builder.command("CreatePizza") { attribute :name, String }
#   builder.scope :large, size: "L"
#   builder.port(:guest) { allow :find, :all }
#   agg = builder.build  # => #<Aggregate name="Pizza" ...>
#
module Hecks
  module DSL
    class AggregateBuilder
      include AttributeCollector

      attr_reader :attributes, :commands, :value_objects, :policies, :validations, :invariants, :scopes, :ports, :queries, :subscribers, :indexes

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
        @subscribers = []
        @indexes = []
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
        if block && block.arity > 0
          # Guard policy: block takes a command argument
          @policies << DomainModel::Behavior::Policy.new(name: name, block: block)
        else
          # Reactive policy: block configures on/trigger/async
          builder = PolicyBuilder.new(name)
          builder.instance_eval(&block) if block
          @policies << builder.build
        end
      end


      def validation(field, rules)
        @validations << DomainModel::Structure::Validation.new(field: field, rules: rules)
      end

      def invariant(message, &block)
        @invariants << DomainModel::Structure::Invariant.new(message: message, block: block)
      end

      def scope(name, conditions_or_lambda = nil, &block)
        conditions = block || conditions_or_lambda
        @scopes << DomainModel::Structure::Scope.new(name: name, conditions: conditions)
      end

      def query(name, &block)
        @queries << DomainModel::Behavior::Query.new(name: name, block: block)
      end

      def index(*fields, unique: false)
        @indexes << { fields: fields.map(&:to_sym), unique: unique }
      end

      def on_event(event_name, async: false, &block)
        name = generate_subscriber_name(event_name.to_s)
        @subscribers << DomainModel::Behavior::EventSubscriber.new(
          name: name, event_name: event_name.to_s, block: block, async: async
        )
      end

      def port(name, &block)
        port_builder = PortBuilder.new(name)
        port_builder.instance_eval(&block) if block
        @ports[name] = port_builder.build
      end

      def build
        events = infer_events

        DomainModel::Structure::Aggregate.new(
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
          queries: @queries,
          subscribers: @subscribers,
          indexes: @indexes
        )
      end

      private

      def generate_subscriber_name(event_name)
        base = "On#{event_name}"
        existing = @subscribers.count { |s| s.event_name == event_name }
        existing.zero? ? base : "#{base}#{existing + 1}"
      end

      def infer_events
        @commands.map do |command|
          DomainModel::Behavior::DomainEvent.new(
            name: command.inferred_event_name,
            attributes: command.attributes
          )
        end
      end
    end
  end
end
