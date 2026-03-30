require_relative "event_builder"
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
      Structure = DomainModel::Structure
      Behavior  = DomainModel::Behavior

      include AttributeCollector
      include BehaviorMethods
      include ConstraintMethods
      include QueryMethods
      include ImplicitSyntax

      # Facet registry — add new aggregate facets without modifying this class.
      #
      #   Hecks::DSL::AggregateBuilder.register_facet(:sagas) do |builder|
      #     builder.define_method(:saga) do |name, &block|
      #       @sagas << { name: name, block: block }
      #     end
      #   end
      #
      @facet_registry = {}

      class << self
        attr_reader :facet_registry

        def register_facet(name, &setup)
          @facet_registry[name] = setup
        end
      end

      attr_reader :attributes, :commands, :value_objects, :entities,
                  :policies, :validations, :invariants, :scopes, :ports,
                  :queries, :subscribers, :indexes, :specifications,
                  :references
      # Writer for lifecycle — used by AggregateHandle to update lifecycle
      # without reaching into instance variables. Reader is the DSL method
      # in BehaviorMethods; use current_lifecycle to read.
      attr_writer :lifecycle

      def current_lifecycle
        @lifecycle
      end

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
        @references = []
        @explicit_events = []
        @lifecycle = nil
        @versioned = false
        @attachable = false
        @metadata = {}
        @facet_data = {}
        self.class.facet_registry.each do |facet_name, setup|
          @facet_data[facet_name] = []
          setup.call(self.class) unless self.class.method_defined?(facet_name)
        end
      end

      def versioned
        @versioned = true
      end

      def attachable
        @attachable = true
      end

      # Declare a relationship to another type.
      # The kind (composition/aggregation/cross-context) is inferred after build:
      #   reference_to "LineItem"              — entity/VO in current agg → composition
      #   reference_to "Order"                 — aggregate root → aggregation
      #   reference_to "Billing::Invoice"      — cross-domain aggregate → cross-context
      #   reference_to "Stakeholder", as: :reviewer  — named role
      #
      def reference_to(type, as: nil)
        @references ||= []
        type_str = type.to_s
        parts = type_str.split("::")
        target = parts.last
        domain = parts.length > 1 ? parts[0..-2].join("::") : nil
        name = as || target.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                           .gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
        @references << { name: name, type: target, domain: domain, kind: nil }
        { reference: type }
      end

      def ref(type, **opts) = reference_to(type, **opts)

      # Declare an explicit domain event (not inferred from a command).
      # Use for time-based, external, or computed events.
      #
      #   event "PolicyExpired" do
      #     attribute :policy_id, String
      #   end
      #
      def event(name, &block)
        builder = EventBuilder.new(name)
        builder.instance_eval(&block) if block
        @explicit_events << builder.build
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
        events = merge_events(infer_events, @explicit_events)

        Structure::Aggregate.new(
          name: @name, attributes: @attributes,
          value_objects: @value_objects, entities: @entities,
          commands: @commands, events: events, policies: @policies,
          validations: @validations, invariants: @invariants,
          scopes: @scopes, ports: @ports, queries: @queries,
          subscribers: @subscribers, indexes: @indexes,
          specifications: @specifications, lifecycle: @lifecycle,
          versioned: @versioned, attachable: @attachable,
          metadata: @metadata, references: @references
        )
      end

      private

      def merge_events(inferred, explicit)
        by_name = {}
        inferred.each { |e| by_name[e.name] = e }
        explicit.each { |e| by_name[e.name] = e }
        by_name.values
      end

      def infer_events
        aggregate_id_attr = Structure::Attribute.new(name: :aggregate_id, type: String)
        @commands.map do |command|
          event_attrs = [aggregate_id_attr] + command.attributes.dup
          @attributes.each do |agg_attr|
            next if event_attrs.any? { |a| a.name == agg_attr.name }
            event_attrs << agg_attr
          end
          Behavior::DomainEvent.new(
            name: command.inferred_event_name,
            attributes: event_attrs
          )
        end
      end
    end
  end
end
