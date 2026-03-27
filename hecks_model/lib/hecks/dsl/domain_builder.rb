module Hecks
  module DSL

    # Hecks::DSL::DomainBuilder
    #
    # Top-level DSL builder for domain definitions. Collects aggregate definitions
    # and domain-level policies, then builds a DomainModel::Structure::Domain.
    # Enforces unique aggregate names. Domain-level policies are cross-aggregate
    # reactive policies defined outside any aggregate block.
    #
    #   Hecks.domain "Banking" do
    #     aggregate "Loan" do ... end
    #     aggregate "Account" do ... end
    #
    #     policy "DisburseFunds" do
    #       on "IssuedLoan"
    #       trigger "Deposit"
    #       map principal: :amount
    #     end
    #   end
    #
    # Builds a DomainModel::Structure::Domain from top-level DSL declarations.
    #
    # DomainBuilder is the entry point for defining an entire domain model. It
    # collects aggregate definitions, cross-aggregate reactive policies, domain
    # services, read model views, workflows, event subscribers, and tenancy
    # configuration. The +#build+ method assembles these into an immutable
    # Domain IR (intermediate representation) object.
    #
    # Aggregates names must be unique within a domain; attempting to define
    # a duplicate raises +ArgumentError+. Errors within aggregate blocks are
    # wrapped in +Hecks::ValidationError+ with context about which aggregate
    # failed.
    #
    # Includes AttributeCollector for domain-level attribute declarations
    # (rarely used, but available for domain metadata).
    class DomainBuilder
      include AttributeCollector

      # Initialize a new domain builder with the given domain name.
      #
      # Sets up empty collections for all domain-level elements.
      #
      # @param name [String] the domain name (e.g. "Banking", "PizzaShop")
      def initialize(name)
        @name = name
        @aggregates = []
        @policies = []
        @services = []
        @views = []
        @workflows = []
        @attributes = []
        @tenancy = nil
        @event_subscribers = []
      end

      # Set the multi-tenancy strategy for this domain.
      #
      # Configures how the runtime isolates data between tenants. The strategy
      # is passed to the TenancySupport extension at boot time.
      #
      # @param strategy [Symbol, String] the tenancy strategy (e.g. :row, :schema)
      # @return [void]
      def tenancy(strategy)
        @tenancy = strategy.to_sym
      end

      # Define a domain service with the given name and optional configuration block.
      #
      # Domain services orchestrate operations that span multiple aggregates.
      # The block is evaluated in the context of a ServiceBuilder.
      #
      # @param name [String] the service name (e.g. "TransferMoney")
      # @yield block evaluated in the context of ServiceBuilder
      # @return [void]
      def service(name, &block)
        builder = ServiceBuilder.new(name)
        builder.instance_eval(&block) if block
        @services << builder.build
      end

      # Register a domain-level event subscriber for the given event.
      #
      # Domain-level subscribers react to events from any aggregate in the
      # domain. They are distinct from aggregate-level subscribers which
      # are scoped to a single aggregate.
      #
      # @param event_name [Symbol, String] the event name to subscribe to
      # @yield block invoked when the event fires
      # @return [void]
      def on_event(event_name, &block)
        @event_subscribers << { event_name: event_name.to_s, block: block }
      end

      # Load partial domain definitions from a file.
      #
      # Reads the given file and evaluates its contents within this builder's
      # context, allowing domain definitions to be split across multiple files.
      # The path is resolved relative to +@_source_dir+ (if set) or +Dir.pwd+.
      #
      # @param path [String] relative or absolute path to a Ruby file containing DSL definitions
      # @return [void]
      #
      # @example
      #   load_from "domain/aggregates/models.rb"
      def load_from(path)
        full = File.expand_path(path, @_source_dir || Dir.pwd)
        instance_eval(File.read(full), full, 1)
      end

      # Define an aggregate root; raises on duplicate names.
      #
      # Creates an AggregateBuilder, evaluates the block within it, and adds
      # the resulting Aggregate IR to the domain. Duplicate aggregate names
      # raise +ArgumentError+. Errors within the block (other than Hecks::Error
      # subclasses) are wrapped in +Hecks::ValidationError+ with context.
      #
      # @param name [String] the aggregate root name (e.g. "Pizza", "Account")
      # @yield block evaluated in the context of AggregateBuilder
      # @return [void]
      # @raise [ArgumentError] if an aggregate with the same name already exists
      # @raise [Hecks::ValidationError] if the block raises a non-Hecks error
      def aggregate(name, description = nil, &block)
        if @aggregates.any? { |a| a.name == name }
          raise ArgumentError, "Duplicate aggregate name: #{name}"
        end

        builder = AggregateBuilder.new(name)
        builder.instance_variable_get(:@metadata)[:description] = description if description
        begin
          builder.instance_eval(&block) if block
        rescue Hecks::Error
          raise
        rescue => e
          raise Hecks::ValidationError, "Error in aggregate '#{name}': #{e.message}"
        end
        @aggregates << builder.build
      end

      # Define a cross-aggregate reactive policy.
      #
      # Domain-level policies react to events from one aggregate and trigger
      # commands on another, enabling decoupled cross-context workflows.
      # The block is evaluated in the context of a PolicyBuilder.
      #
      # @param name [String] the policy name (e.g. "DisburseFunds")
      # @yield block evaluated in the context of PolicyBuilder
      # @return [void]
      def policy(name, &block)
        builder = PolicyBuilder.new(name)
        builder.instance_eval(&block) if block
        @policies << builder.build
      end

      # Define a read model (view) projected from domain events.
      #
      # Read models are denormalized projections built by applying event
      # handlers. The block is evaluated in the context of a ReadModelBuilder.
      #
      # @param name [String] the read model name (e.g. "OrderSummary")
      # @yield block evaluated in the context of ReadModelBuilder
      # @return [void]
      def view(name, &block)
        builder = ReadModelBuilder.new(name)
        builder.instance_eval(&block) if block
        @views << builder.build
      end

      # Define a multi-step workflow composed of commands and branches.
      #
      # Workflows orchestrate sequences of commands with optional branching
      # logic based on specification predicates. The block is evaluated in
      # the context of a WorkflowBuilder.
      #
      # @param name [String] the workflow name (e.g. "LoanApproval")
      # @yield block evaluated in the context of WorkflowBuilder
      # @return [void]
      def workflow(name, &block)
        builder = WorkflowBuilder.new(name)
        builder.instance_eval(&block) if block
        @workflows << builder.build
      end

      # Implicit DSL support. PascalCase calls at the domain level create aggregates.
      # Example: `Pizza do ... end` is sugar for `aggregate "Pizza" do ... end`
      def method_missing(name, *args, &block)
        if name.to_s =~ /\A[A-Z]/ && block_given?
          desc = args.first.is_a?(String) ? args.first : nil
          aggregate(name.to_s, desc, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        name.to_s =~ /\A[A-Z]/ || super
      end

      # Build and return the DomainModel::Structure::Domain IR object.
      #
      # Assembles all collected domain-level elements into an immutable
      # Domain intermediate representation.
      #
      # @return [DomainModel::Structure::Domain] the fully built domain IR object
      def build
        DomainModel::Structure::Domain.new(
          name: @name, aggregates: @aggregates, policies: @policies,
          services: @services, views: @views, workflows: @workflows,
          tenancy: @tenancy, event_subscribers: @event_subscribers
        )
      end
    end
  end
end
