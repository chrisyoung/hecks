module Hecks
  module DSL

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
    # Builds a DomainModel::Structure::Aggregate from DSL declarations.
    #
    # AggregateBuilder is the primary builder used inside +aggregate+ blocks in
    # the Hecks DSL. It collects every facet of an aggregate root definition --
    # attributes, nested value objects and entities, commands, policies,
    # validations, invariants, scopes, ports, queries, specifications, indexes,
    # event subscribers, lifecycle state machines, versioning, and attachment
    # support -- and produces an immutable Aggregate IR (intermediate
    # representation) object via +#build+.
    #
    # Domain events are automatically inferred from declared commands: each
    # command produces one event whose name is derived from the command name
    # (e.g. "CreatePizza" => "CreatedPizza"). Event attributes are the union
    # of the command's attributes, an +aggregate_id+ field, and the aggregate's
    # own attributes.
    #
    # Includes AttributeCollector for the +attribute+, +list_of+, and
    # +reference_to+ DSL methods.
    class AggregateBuilder
      include AttributeCollector

      # @return [Array<DomainModel::Structure::Attribute>] declared attributes on the aggregate root
      # @return [Array<DomainModel::Behavior::Command>] commands that can be issued against this aggregate
      # @return [Array<DomainModel::Structure::ValueObject>] nested value objects owned by this aggregate
      # @return [Array<DomainModel::Structure::Entity>] nested entities owned by this aggregate
      # @return [Array<DomainModel::Behavior::Policy>] guard and reactive policies attached to this aggregate
      # @return [Array<DomainModel::Structure::Validation>] field-level validation rules
      # @return [Array<DomainModel::Structure::Invariant>] aggregate-level invariant constraints
      # @return [Array<DomainModel::Structure::Scope>] named query scopes with conditions
      # @return [Hash{Symbol => DomainModel::Structure::PortDefinition}] access ports keyed by role name
      # @return [Array<DomainModel::Behavior::Query>] custom query definitions
      # @return [Array<DomainModel::Behavior::EventSubscriber>] event subscriber handlers
      # @return [Array<Hash>] declared database indexes, each with :fields and :unique keys
      # @return [Array<DomainModel::Behavior::Specification>] reusable specification predicates
      attr_reader :attributes, :commands, :value_objects, :entities, :policies, :validations, :invariants, :scopes, :ports, :queries, :subscribers, :indexes, :specifications

      # Initialize a new aggregate builder with the given aggregate name.
      #
      # Sets up empty collections for all aggregate facets. No attributes,
      # commands, or other elements are defined until DSL methods are called.
      #
      # @param name [String] the name of the aggregate root (e.g. "Pizza", "Account")
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
      end

      # Mark this aggregate as versioned for optimistic concurrency control.
      #
      # When versioned, the runtime adds a +version+ field and checks it on
      # every update to prevent lost-update conflicts.
      #
      # @return [void]
      def versioned
        @versioned = true
      end

      # Define a state machine lifecycle on the given field.
      #
      # Creates a LifecycleBuilder, evaluates the block within it, and stores
      # the resulting Lifecycle IR object. Only one lifecycle per aggregate is
      # supported; calling this again overwrites the previous lifecycle.
      #
      # @param field [Symbol] the attribute that holds the state value (e.g. :status)
      # @param default [String] the initial state value (e.g. "draft")
      # @yield block evaluated in the context of LifecycleBuilder to define transitions
      # @return [void]
      def lifecycle(field, default:, &block)
        builder = LifecycleBuilder.new(field, default: default)
        builder.instance_eval(&block) if block
        @lifecycle = builder.build
      end

      # Mark this aggregate as supporting file attachments.
      #
      # When attachable, the runtime adds attachment handling infrastructure
      # to the aggregate.
      #
      # @return [void]
      def attachable
        @attachable = true
      end

      # Define a nested value object within this aggregate.
      #
      # Value objects are immutable, equality-by-value types embedded within
      # the aggregate. The block is evaluated in the context of a
      # ValueObjectBuilder to collect attributes and invariants.
      #
      # @param name [String] the value object type name (e.g. "Address")
      # @yield block evaluated in the context of ValueObjectBuilder
      # @return [void]
      def value_object(name, &block)
        builder = ValueObjectBuilder.new(name)
        builder.instance_eval(&block) if block
        @value_objects << builder.build
      end

      # Define a nested entity within this aggregate.
      #
      # Entities have identity (UUID), are mutable, and use identity-based
      # equality. The block is evaluated in the context of an EntityBuilder
      # to collect attributes and invariants.
      #
      # @param name [String] the entity type name (e.g. "LedgerEntry")
      # @yield block evaluated in the context of EntityBuilder
      # @return [void]
      def entity(name, &block)
        builder = EntityBuilder.new(name)
        builder.instance_eval(&block) if block
        @entities << builder.build
      end

      # Define a command that can be issued against this aggregate.
      #
      # Each command automatically gets a corresponding domain event inferred
      # by name (e.g. "CreatePizza" => "CreatedPizza"). The block is evaluated
      # in the context of a CommandBuilder to collect attributes, guards,
      # read models, actors, and other command metadata.
      #
      # @param name [String] the command name (e.g. "CreatePizza")
      # @yield block evaluated in the context of CommandBuilder
      # @return [void]
      def command(name, &block)
        builder = CommandBuilder.new(name)
        builder.instance_eval(&block) if block
        @commands << builder.build
      end

      # Define a guard or reactive policy on this aggregate.
      #
      # The method distinguishes between two policy types based on the block's
      # arity:
      # - Guard policy (arity > 0): the block receives a command argument and
      #   acts as a pre-execution check.
      # - Reactive policy (arity == 0 or no block): the block configures
      #   event-to-command wiring via PolicyBuilder DSL methods (+on+,
      #   +trigger+, +async+, +map+, +condition+).
      #
      # @param name [String] the policy name (e.g. "MustBeAdmin", "FraudAlert")
      # @yield block for guard check (receives command) or reactive wiring (PolicyBuilder context)
      # @return [void]
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


      # Add a field-level validation rule (e.g. presence, format).
      #
      # @param field [Symbol] the attribute name to validate
      # @param rules [Hash] validation rules (e.g. +{ presence: true, format: /\A[A-Z]/ }+)
      # @return [void]
      def validation(field, rules)
        @validations << DomainModel::Structure::Validation.new(field: field, rules: rules)
      end

      # Define an aggregate-level invariant with an error message and check block.
      #
      # Invariants are boolean conditions that must always hold true for the
      # aggregate to be in a valid state. They are checked after every command.
      #
      # @param message [String] human-readable description of the invariant
      # @yield block that returns true when the invariant holds, false when violated
      # @return [void]
      def invariant(message, &block)
        @invariants << DomainModel::Structure::Invariant.new(message: message, block: block)
      end

      # Define a named query scope with conditions or a lambda.
      #
      # Scopes provide pre-defined filters for repository queries. They can be
      # specified as a hash of conditions, a lambda, or a block.
      #
      # @param name [Symbol] the scope name (e.g. :large, :active)
      # @param conditions_or_lambda [Hash, Proc, nil] filter conditions or a callable
      # @yield optional block used as the conditions if no positional argument given
      # @return [void]
      def scope(name, conditions_or_lambda = nil, &block)
        conditions = block || conditions_or_lambda
        @scopes << DomainModel::Structure::Scope.new(name: name, conditions: conditions)
      end

      # Define a custom query with a block for complex lookups.
      #
      # Unlike scopes (which are simple filters), queries can contain arbitrary
      # logic for complex data retrieval patterns.
      #
      # @param name [Symbol] the query name
      # @yield block implementing the query logic
      # @return [void]
      def query(name, &block)
        @queries << DomainModel::Behavior::Query.new(name: name, block: block)
      end

      # Define a reusable specification predicate for this aggregate.
      #
      # Specifications are named boolean predicates that can be composed and
      # reused across queries, workflow branches, and policy conditions.
      #
      # @param name [Symbol, String] the specification name (e.g. :high_risk)
      # @yield block that receives an aggregate instance and returns true/false
      # @return [void]
      def specification(name, &block)
        @specifications << DomainModel::Behavior::Specification.new(name: name, block: block)
      end

      # Declare a database index on one or more fields.
      #
      # Indexes are used by persistence adapters to create database indexes
      # for performance optimization.
      #
      # @param fields [Array<Symbol>] one or more field names to index
      # @param unique [Boolean] whether the index enforces uniqueness (default: false)
      # @return [void]
      def index(*fields, unique: false)
        @indexes << { fields: fields.map(&:to_sym), unique: unique }
      end

      # Subscribe to a domain event with an optional async flag.
      #
      # Registers a handler block that runs when the named event is published.
      # Multiple subscribers to the same event are supported; subscriber names
      # are auto-generated to avoid conflicts.
      #
      # @param event_name [Symbol, String] the domain event to subscribe to
      # @param async [Boolean] whether to execute the handler asynchronously (default: false)
      # @yield block invoked when the event fires
      # @return [void]
      def on_event(event_name, async: false, &block)
        name = generate_subscriber_name(event_name.to_s)
        @subscribers << DomainModel::Behavior::EventSubscriber.new(
          name: name, event_name: event_name.to_s, block: block, async: async
        )
      end

      # Define an access port restricting allowed operations for a role.
      #
      # Ports control which repository and command operations are available
      # to a given role. The block is evaluated in the context of a PortBuilder.
      #
      # @param name [Symbol] the role or port name (e.g. :guest, :admin)
      # @yield block evaluated in the context of PortBuilder to declare allowed methods
      # @return [void]
      def port(name, methods = nil, &block)
        port_builder = PortBuilder.new(name)
        if methods
          # Compact form: port :admin, [:find, :all, :create]
          methods.each { |m| port_builder.allow(m) }
        end
        port_builder.instance_eval(&block) if block
        @ports[name] = port_builder.build
      end

      # Alias for reference_to, used in the implicit DSL.
      # Example: `pizza_id ref("Pizza")` instead of `pizza_id reference_to("Pizza")`
      def ref(name) = reference_to(name)

      # Implicit DSL support within aggregates.
      # - PascalCase with block → value_object
      # - snake_case with block → command (name inferred from aggregate)
      # - name Type → attribute
      def method_missing(name, *args, **kwargs, &block)
        name_s = name.to_s
        if name_s =~ /\A[A-Z]/ && block_given?
          value_object(name_s, &block)
        elsif block_given?
          cmd_name = infer_command_name(name_s)
          command(cmd_name, &block)
        elsif args.first.is_a?(Class) || (args.first.is_a?(String) && args.first =~ /\A[A-Z]/)
          attribute(name, args.first, **kwargs)
        elsif args.first.is_a?(Hash) && (args.first[:list] || args.first[:reference])
          attribute(name, args.first, **kwargs)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        true # Accept anything in implicit mode
      end

      # Build and return the DomainModel::Structure::Aggregate IR object.
      #
      # Finalizes the aggregate definition by inferring domain events from
      # the declared commands and assembling all collected facets into an
      # immutable Aggregate intermediate representation.
      #
      # @return [DomainModel::Structure::Aggregate] the fully built aggregate IR object
      def build
        events = infer_events

        DomainModel::Structure::Aggregate.new(
          name: @name,
          attributes: @attributes,
          value_objects: @value_objects,
          entities: @entities,
          commands: @commands,
          events: events,
          policies: @policies,
          validations: @validations,
          invariants: @invariants,
          scopes: @scopes,
          ports: @ports,
          queries: @queries,
          subscribers: @subscribers,
          indexes: @indexes,
          specifications: @specifications,
          lifecycle: @lifecycle,
          versioned: @versioned,
          attachable: @attachable
        )
      end

      private

      # Infer a PascalCase command name from a snake_case method name.
      # Single verbs get the aggregate name appended: create → CreatePizza
      # Multi-word names are PascalCased as-is: add_topping → AddTopping
      def infer_command_name(snake)
        parts = snake.split("_")
        if parts.size == 1
          # Single verb → verb + aggregate name
          parts.first.capitalize + @name
        else
          # Multi-word → PascalCase
          parts.map(&:capitalize).join
        end
      end

      # Generate a unique subscriber name for an event.
      #
      # If this is the first subscriber for the event, returns "On<EventName>".
      # For subsequent subscribers, appends a numeric suffix (e.g. "OnFoo2").
      #
      # @param event_name [String] the event name
      # @return [String] a unique subscriber name
      def generate_subscriber_name(event_name)
        base = "On#{event_name}"
        existing = @subscribers.count { |s| s.event_name == event_name }
        existing.zero? ? base : "#{base}#{existing + 1}"
      end

      # Infer domain events from the declared commands.
      #
      # Each command produces one event. The event name is derived from the
      # command via +Command#inferred_event_name+ (e.g. "CreatePizza" =>
      # "CreatedPizza"). Event attributes are the union of:
      # 1. An +aggregate_id+ (String) field
      # 2. The command's own attributes
      # 3. Any aggregate-level attributes not already present
      #
      # @return [Array<DomainModel::Behavior::DomainEvent>] inferred events
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
