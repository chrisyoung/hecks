module Hecksagon
  module DSL

    # Hecksagon::DSL::HecksagonBuilder
    #
    # DSL builder for hexagonal architecture wiring. Collects gates, adapter
    # config, extensions, cross-domain subscriptions, and tenancy strategy.
    #
    #   builder = HecksagonBuilder.new("Pizzas")
    #   builder.gate("Pizza", :admin) { allow :find, :all }
    #   builder.adapter :sqlite, database: "app.db"
    #   hex = builder.build
    #
    class HecksagonBuilder
      def initialize(name = nil)
        @name = name
        @gates = []
        @adapter = nil
        @extensions = []
        @subscriptions = []
        @tenancy = nil
        @aggregate_capabilities = {}
      end

      # Declare a gate (access control) for an aggregate + role.
      #
      # @param aggregate [String] the aggregate name
      # @param role [Symbol] the role name
      # @yield block evaluated in GateBuilder context
      # @return [void]
      def gate(aggregate, role, &block)
        builder = GateBuilder.new(aggregate, role)
        builder.instance_eval(&block) if block
        @gates << builder.build
      end

      # Configure the persistence adapter.
      #
      # @param type [Symbol] adapter type (:memory, :sqlite, :postgres, etc.)
      # @param options [Hash] adapter-specific options (e.g., database:, host:)
      # @return [void]
      def adapter(type, **options)
        @adapter = { type: type }.merge(options)
      end

      # Register an extension.
      #
      # @param name [Symbol] extension name (e.g., :audit, :rate_limit)
      # @param options [Hash] extension-specific options
      # @return [void]
      def extension(name, **options)
        @extensions << { name: name.to_sym }.merge(options)
      end

      # Subscribe to events from another domain.
      #
      # @param domain_name [String] the source domain to listen to
      # @return [void]
      def subscribe(domain_name)
        @subscriptions << domain_name.to_s
      end

      # Set the multi-tenancy strategy.
      #
      # @param strategy [Symbol] tenancy strategy (:row, :schema, etc.)
      # @return [void]
      def tenancy(strategy)
        @tenancy = strategy.to_sym
      end

      # Declare attribute-level capabilities for an aggregate.
      #
      #   capabilities "Customer" do
      #     email.privacy
      #     ssn.privacy.searchable
      #   end
      #
      # @param aggregate_name [String] the aggregate name
      # @yield block evaluated in AggregateCapabilityBuilder context
      # @return [void]
      def capabilities(aggregate_name, &block)
        builder = AggregateCapabilityBuilder.new(aggregate_name)
        builder.instance_eval(&block) if block
        @aggregate_capabilities[aggregate_name.to_s] = builder.build
      end

      # Build and return the Hecksagon IR object.
      #
      # @return [Hecksagon::Structure::Hecksagon]
      def build
        Structure::Hecksagon.new(
          name: @name,
          gates: @gates,
          adapter: @adapter,
          extensions: @extensions,
          subscriptions: @subscriptions,
          tenancy: @tenancy,
          aggregate_capabilities: @aggregate_capabilities
        )
      end
    end
  end
end
