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
        @concerns = []
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

      # Declare world concerns for this hecksagon.
      #
      # Concerns are resolved at boot time to extensions and capabilities
      # via Hecks::Concerns::Mapping.
      #
      # @param names [Array<Symbol>] concern names (e.g., :transparency, :privacy)
      # @return [void]
      def concerns(*names)
        @concerns = names.flatten.map(&:to_sym)
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
          concerns: @concerns
        )
      end
    end
  end
end
