require_relative "aggregate_handle/presenter"
require_relative "command_handle"

module Hecks
  class Workbench
    # Hecks::Workbench::AggregateHandle
    #
    # Interactive handle for incrementally building a single aggregate in the
    # REPL. Wraps an AggregateBuilder and provides add/remove methods that
    # print feedback as you go. Supports one-line dot syntax via method_missing.
    #
    # Part of the Session layer -- returned by Session#aggregate to allow
    # step-by-step aggregate construction without full DSL blocks.
    #
    #   Post.title String         # implicit attribute
    #   Post.create               # implicit command, returns CommandHandle
    #   Post.create.title String  # add attribute to command
    #   Post.lifecycle :status, default: "draft"
    #   Post.transition "PublishPost" => "published"
    #
    class AggregateHandle
    include Presenter

    attr_reader :name

    # Create a new AggregateHandle wrapping a builder.
    #
    # @param name [String] the sanitized aggregate name
    # @param builder [DSL::AggregateBuilder] the underlying builder for this aggregate
    # @param domain_module [String] the domain module name (e.g. "PizzasDomain")
    # @param workbench [Session, nil] the parent workbench, used for cross-aggregate checks
    def initialize(name, builder, domain_module:, workbench: nil)
      @name = name
      @builder = builder
      @domain_module = domain_module
      @workbench = workbench
      @command_handles = {}
    end

    # Add an attribute to the aggregate.
    #
    # Checks for duplicate attribute names before adding. Supports plain types
    # (String, Integer), list types ({list: String}), and reference types
    # ({reference: "Order"}). When a reference type is used, checks for
    # bidirectional reference warnings.
    #
    # @param name [Symbol, String] the attribute name
    # @param type [Class, Hash] the attribute type (default: String)
    # @param options [Hash] additional options passed to the builder (e.g. optional: true)
    # @return [AggregateHandle] self, for chaining
    # @raise [ArgumentError] if an attribute with the same name already exists
    def attr(name, type = String, **options)
      check_duplicate_attr!(name)
      @builder.attribute(name, type, **options)
      if type.is_a?(Hash) && type[:reference]
        puts "#{name} reference added to #{@name} -> #{type[:reference]}"
        check_bidirectional(type[:reference])
      else
        puts "#{name} attribute added to #{@name}"
      end
      self
    end

    # Remove an attribute from the aggregate by name.
    #
    # @param name [Symbol, String] the attribute name to remove
    # @return [AggregateHandle] self, for chaining
    def remove(name)
      attrs = @builder.attributes
      removed = attrs.reject! { |a| a.name == name.to_sym }
      if removed
        puts "#{name} attribute removed from #{@name}"
      else
        puts "no attribute #{name} on #{@name}"
      end
      self
    end

    # Add a value object to the aggregate.
    #
    # @param name [String] the value object name (will be sanitized)
    # @yield block evaluated on the value object builder to define attributes/invariants
    # @return [AggregateHandle] self, for chaining
    def value_object(name, &block)
      name = normalize_name(name)
      @builder.value_object(name, &block)
      puts "#{name} value object created on #{@name}"
      self
    end

    # Add an entity to the aggregate.
    #
    # @param name [String] the entity name (will be sanitized)
    # @yield block evaluated on the entity builder to define attributes
    # @return [AggregateHandle] self, for chaining
    def entity(name, &block)
      name = normalize_name(name)
      @builder.entity(name, &block)
      puts "#{name} entity created on #{@name}"
      self
    end

    # Add a command to the aggregate.
    #
    # Commands automatically generate a corresponding event (e.g. CreatePizza
    # generates CreatedPizza). The inferred event name is printed as feedback.
    #
    # @param name [String] the command name (will be sanitized)
    # @yield block evaluated on the command builder to define attributes
    # @return [AggregateHandle] self, for chaining
    def command(name, &block)
      name = normalize_name(name)
      @builder.command(name, &block)
      puts "#{name} command created on #{@name}"
      self
    end

    # Add a field-level validation to the aggregate.
    #
    # @param field [Symbol] the attribute name to validate
    # @param rules [Hash] validation rules (e.g. {presence: true, format: /\A[A-Z]/})
    # @return [AggregateHandle] self, for chaining
    def validation(field, rules)
      @builder.validation(field, rules)
      puts "#{field} validation added to #{@name} (#{rules.keys.join(', ')})"
      self
    end

    # Add an aggregate-level invariant (business rule).
    #
    # @param message [String] human-readable description of the invariant
    # @yield block that returns true when the invariant holds
    # @return [AggregateHandle] self, for chaining
    def invariant(message, &block)
      @builder.invariant(message, &block)
      puts "invariant added to #{@name}: #{message}"
      self
    end

    # Add a reactive policy to the aggregate.
    #
    # Policies listen for an event and trigger a command in response.
    # The event and trigger command are printed as feedback.
    #
    # @param name [String] the policy name (will be sanitized)
    # @yield block evaluated on the policy builder to define event/trigger
    # @return [AggregateHandle] self, for chaining
    def policy(name, &block)
      name = normalize_name(name)
      @builder.policy(name, &block)
      puts "#{name} policy created on #{@name}"
      self
    end

    # Register a custom verb on the parent workbench.
    #
    # Custom verbs extend command name recognition (e.g. "Bake", "Ferment").
    #
    # @param word [String, Symbol] the verb to register
    # @return [AggregateHandle] self, for chaining
    def verb(word)
      @workbench&.add_verb(word)
      puts "#{word} verb registered"
      self
    end

    # Add a named query to the aggregate.
    #
    # @param name [Symbol, String] the query name
    # @yield block defining the query logic
    # @return [AggregateHandle] self, for chaining
    def query(name, &block)
      @builder.query(name, &block)
      puts "#{name} query added to #{@name}"
      self
    end

    # Add a named scope to the aggregate for filtering collections.
    #
    # @param name [Symbol, String] the scope name
    # @param conditions [Hash, nil] optional static conditions hash
    # @yield optional block for dynamic scope logic
    # @return [AggregateHandle] self, for chaining
    def scope(name, conditions = nil, &block)
      @builder.scope(name, conditions, &block)
      puts "#{name} scope added to #{@name}"
      self
    end

    # Add a specification (predicate object) to the aggregate.
    #
    # @param name [String] the specification name (will be sanitized)
    # @yield block defining the specification predicate
    # @return [AggregateHandle] self, for chaining
    def specification(name, &block)
      name = normalize_name(name)
      @builder.specification(name, &block)
      puts "#{name} specification added to #{@name}"
      self
    end

    # Subscribe to an event with a handler block.
    #
    # @param event_name [String] the event name to listen for
    # @param async [Boolean] whether the handler runs asynchronously (default: false)
    # @yield block to execute when the event is published
    # @return [AggregateHandle] self, for chaining
    def on_event(event_name, async: false, &block)
      @builder.on_event(event_name, async: async, &block)
      puts "#{event_name} subscriber added to #{@name}"
      self
    end

    # List all attribute names defined on this aggregate.
    #
    # @return [Array<Symbol>] attribute names
    def attributes
      @builder.attributes.map(&:name)
    end

    # List all command names defined on this aggregate.
    #
    # @return [Array<String>] command names
    def commands
      @builder.commands.map(&:name)
    end

    # List all value object names defined on this aggregate.
    #
    # @return [Array<String>] value object names
    def value_objects
      @builder.value_objects.map { |vo| vo.is_a?(DomainModel::Structure::ValueObject) ? vo.name : vo.build.name }
    end

    # List all entity names defined on this aggregate.
    #
    # @return [Array<String>] entity names
    def entities
      @builder.entities.map { |ent| ent.is_a?(DomainModel::Structure::Entity) ? ent.name : ent.build.name }
    end

    # Add a lifecycle state machine to the aggregate.
    #
    #   Post.lifecycle :status, default: "draft"
    #
    # @param field [Symbol] the attribute that holds the state
    # @param default [String] the initial state value
    # @yield optional block with transition declarations
    # @return [AggregateHandle] self, for chaining
    def lifecycle(field, default:, &block)
      @builder.lifecycle(field, default: default, &block)
      puts "lifecycle added to #{@name} on #{field}, default: #{default}"
      self
    end

    # Add a lifecycle transition mapping a command to a target state.
    #
    #   Post.transition "PublishPost" => "published"
    #
    # @param mapping [Hash] command name => target state
    # @return [AggregateHandle] self, for chaining
    def transition(mapping)
      @builder.instance_eval { @lifecycle ||= nil }
      lc = @builder.instance_variable_get(:@lifecycle)
      if lc.nil?
        puts "no lifecycle on #{@name} — call lifecycle first"
        return self
      end
      # Rebuild lifecycle with additional transition
      builder = DSL::LifecycleBuilder.new(lc.field, default: lc.default)
      lc.transitions.each { |cmd, target| builder.transition(cmd => target) }
      builder.transition(mapping)
      @builder.instance_variable_set(:@lifecycle, builder.build)
      cmd = mapping.keys.first
      target = mapping.values.first
      puts "#{cmd} transition added -> #{target}"
      self
    end

    # DSL helper to create a list-of type descriptor.
    #
    # @param type [Class] the element type for the list
    # @return [Hash] type descriptor hash, e.g. {list: String}
    def list_of(type)
      { list: type }
    end

    # DSL helper to create a reference-to type descriptor.
    #
    # @param type [String, Class] the referenced aggregate type
    # @return [Hash] type descriptor hash, e.g. {reference: "Order"}
    def reference_to(type)
      { reference: type }
    end

    # Implicit one-line dot syntax via method_missing.
    #
    #   Post.title String          # name + Type → attribute
    #   Post.create                # bare snake_case → command + CommandHandle
    #   Post.create { ... }        # snake_case + block → command with block
    #   Post.Address { ... }       # PascalCase + block → value object
    #
    # @return [AggregateHandle, CommandHandle] self or a CommandHandle for chaining
    def method_missing(name, *args, **kwargs, &block)
      name_s = name.to_s

      if name_s =~ /\A[A-Z]/ && block_given?
        value_object(name_s, &block)
      elsif block_given?
        cmd_name = infer_command_name(name_s)
        command(cmd_name, &block)
      elsif args.first.is_a?(Class) || (args.first.is_a?(String) && args.first =~ /\A[A-Z]/)
        attr(name, args.first, **kwargs)
      elsif args.first.is_a?(Hash) && (args.first[:list] || args.first[:reference])
        attr(name, args.first, **kwargs)
      elsif args.empty? && kwargs.empty? && !block_given?
        cmd_name = infer_command_name(name_s)
        unless @command_handles.key?(cmd_name)
          command(cmd_name)
        end
        @command_handles[cmd_name] ||= CommandHandle.new(cmd_name, @builder, @name)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    private

    # Raise if an attribute with the given name already exists.
    #
    # @param name [Symbol, String] the attribute name to check
    # @raise [ArgumentError] if a duplicate is found
    def check_duplicate_attr!(name)
      if @builder.attributes.any? { |a| a.name == name.to_sym }
        raise ArgumentError, "#{@name} already has attribute :#{name}"
      end
    end

    # Normalize a name into a valid Ruby constant string.
    #
    # @param name [String] the raw name
    # @return [String] sanitized constant name
    def normalize_name(name)
      Hecks::Templating::Names.domain_constant_name(name)
    end

    # Infer a PascalCase command name from a snake_case method name.
    # Single verbs get the aggregate name appended: create → CreatePost
    # Multi-word names are PascalCased as-is: add_topping → AddTopping
    def infer_command_name(snake)
      parts = snake.to_s.split("_")
      if parts.size == 1
        parts.first.capitalize + @name
      else
        parts.map(&:capitalize).join
      end
    end

    # Check for bidirectional references and warn the user.
    #
    # Aggregates should not reference each other; one side should use
    # events/policies instead. This method inspects the target aggregate
    # to see if it already references this aggregate.
    #
    # @param target_name [String] the name of the referenced aggregate
    # @return [void]
    def check_bidirectional(target_name)
      return unless @workbench

      domain = @workbench.to_domain
      target_agg = domain.aggregates.find { |a| a.name == target_name.to_s }
      return unless target_agg

      back_refs = target_agg.attributes.select(&:reference?).map { |a| a.type.to_s }
      if back_refs.include?(@name)
        puts "  !! WARNING: Bidirectional reference detected between #{@name} and #{target_name}."
        puts "     #{target_name} already references #{@name}. Aggregates should not reference"
        puts "     each other — one side should use events/policies instead."
      end
    end
  end
  end
end
