module Hecksagon
  module Structure

    # Hecksagon::Structure::Hecksagon
    #
    # Intermediate representation of the hexagonal architecture wiring for a
    # domain. Holds gates (access control), adapter configuration, extensions,
    # cross-domain subscriptions, and tenancy strategy.
    #
    # Built by the Hecksagon DSL builder, consumed by the runtime boot sequence.
    #
    #   hex = Hecksagon.new(
    #     name: "Pizzas",
    #     gates: [GateDefinition.new(aggregate: "Pizza", role: :admin, allowed_methods: [:find])],
    #     adapter: { type: :sqlite, database: "app.db" },
    #     extensions: [{ name: :audit }],
    #     subscriptions: ["Billing"],
    #     tenancy: :row
    #   )
    #
    class Hecksagon
      attr_reader :name, :gates, :adapter, :extensions, :subscriptions, :tenancy,
                  :capabilities, :aggregate_capabilities

      def initialize(name:, gates: [], adapter: nil, extensions: [], subscriptions: [],
                     tenancy: nil, capabilities: [], aggregate_capabilities: {})
        @name = name
        @gates = gates
        @adapter = adapter
        @extensions = extensions
        @subscriptions = subscriptions
        @tenancy = tenancy
        @capabilities = capabilities
        @aggregate_capabilities = aggregate_capabilities
      end

      # Returns gates for a specific aggregate.
      def gates_for(aggregate_name)
        @gates.select { |g| g.aggregate == aggregate_name.to_s }
      end

      # Returns the gate for a specific aggregate + role combination.
      def gate_for(aggregate_name, role)
        @gates.find { |g| g.aggregate == aggregate_name.to_s && g.role == role.to_sym }
      end

      # Returns attribute names tagged as :indexed for a given aggregate.
      #
      # @param aggregate_name [String, Symbol] the aggregate name
      # @return [Array<String>] attribute names with the :indexed tag
      def indexed_attributes_for(aggregate_name)
        tags = @aggregate_capabilities[aggregate_name.to_s] || []
        tags.select { |t| t[:tag] == :indexed }.map { |t| t[:attribute] }
      end

      # Returns the field names tagged :searchable for the given aggregate.
      #
      # @param aggregate_name [String, Symbol] the aggregate name (e.g., "Pizza")
      # @return [Array<String>] the field names with the :searchable tag
      def searchable_fields(aggregate_name)
        caps = @aggregate_capabilities[aggregate_name.to_s] || []
        caps.select { |c| c[:tag] == :searchable }.map { |c| c[:attribute] }
      end
    end
  end
end
